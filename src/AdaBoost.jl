#!/usr/bin/env bash
    #=
    exec julia --project="$(realpath $(dirname $0))/../" "${BASH_SOURCE[0]}" "$@" -e 'include(popfirst!(ARGS))' \
    "${BASH_SOURCE[0]}" "$@"
    =#


# TODO: select optimal threshold for each feature
# TODO: attentional cascading

using Base.Threads: @threads
using Base.Iterators: partition
using ProgressMeter: @showprogress, Progress, next!

function β(i::T)::T where T
    return @fastmath(T(0.5) * log((one(i) - i) / i))
end

function get_feature_votes(
    positive_path::AbstractString,
    negative_path::AbstractString,
    num_classifiers::Integer=-one(Int32),
    min_feature_width::Integer=one(Int32),
    max_feature_width::Integer=-one(Int32),
    min_feature_height::Integer=one(Int32),
    max_feature_height::Integer=-one(Int32);
    scale::Bool = false,
    scale_to::Tuple = (Int32(200), Int32(200))
    )

    #this transforms everything to maintain type stability
    s₁, s₂ = scale_to
    min_feature_width,
    max_feature_width,
    min_feature_height,
    max_feature_height, s₁, s₂ = promote(
        min_feature_width,
        max_feature_width,
        min_feature_height,
        max_feature_height,
        s₁,
        s₂
    )
    scale_to = (s₁, s₂)
    _Int = typeof(max_feature_width)
    
    # get number of positive and negative image
    positive_files = filtered_ls(positive_path)
    negative_files = filtered_ls(negative_path)
    image_files = vcat(positive_files, negative_files)
    num_pos = length(positive_files)
    num_neg = length(negative_files)
    num_imgs = num_pos + num_neg
    
    # get image height and width
    temp_image = load_image(rand(positive_files), scale=scale, scale_to=scale_to)
    img_height, img_width = size(temp_image)
    temp_image = nothing # unload temporary image
    
    # Maximum feature width and height default to image width and height
    max_feature_height = isequal(max_feature_height, -_Int(1)) ? img_height : max_feature_height
    max_feature_width = isequal(max_feature_width, -_Int(1)) ? img_height : max_feature_width
    
    # Create features for all sizes and locations
    features = create_features(img_height, img_width, min_feature_width, max_feature_width, min_feature_height, max_feature_height)
    num_features = length(features)
    num_classifiers = isequal(num_classifiers, -_Int(1)) ? num_features : num_classifiers
    
    # create an empty array with dimensions (num_imgs, numFeautures)
    votes = Matrix{Int8}(undef, num_features, num_imgs)
    
    notify_user("Loading images ($(num_pos) positive and $(num_neg) negative images) and calculating their scores...")
    p = Progress(length(image_files), 1) # minimum update interval: 1 second
    num_processed = 0
    batch_size = 10
    # get votes for images
    map(partition(image_files, batch_size)) do batch
        ii_imgs = load_image.(batch; scale=scale, scale_to=scale_to)
        @threads for t in 1:length(batch)
            votes[:, num_processed + t] .= get_vote.(features, Ref(ii_imgs[t]))
            # map!(f -> get_vote(f, ii_imgs[t]), view(votes, :, num_processed + t), features)
            next!(p) # increment progress bar
        end
        num_processed += length(batch)
    end
    print("\n") # for a new line after the progress bar
    
    return votes, features
end

function learn(
    positive_path::AbstractString,
    negative_path::AbstractString,
    features::Array{HaarLikeObject, 1},
    votes::Matrix{Int8},
    num_classifiers::Integer=-one(Int32)
    )
    # get number of positive and negative images (and create a global variable of the total number of images——global for the @everywhere scope)
    num_pos = length(filtered_ls(positive_path))
    num_neg = length(filtered_ls(negative_path))
    num_imgs = num_pos + num_neg

    # Initialise weights $w_{1,i} = \frac{1}{2m}, \frac{1}{2l}$, for $y_i=0,1$ for negative and positive examples respectively
    pos_weights = ones(num_pos) / (2 * num_pos)
    neg_weights = ones(num_neg) / (2 * num_neg)

    # Concatenate positive and negative weights into one `weights` array
    weights = vcat(pos_weights, neg_weights)
    labels = vcat(ones(Int8, num_pos), ones(Int8, num_neg) * -one(Int8))
    
    # get number of features
    num_features = length(features)
    feature_indices = Array(1:num_features)
    num_classifiers = isequal(num_classifiers, -1) ? num_features : num_classifiers

    # select classifiers
    notify_user("Selecting classifiers...")
    classifiers = HaarLikeObject[]
    p = Progress(num_classifiers, 1) # minimum update interval: 1 second
    classification_errors = Vector{Float64}(undef, length(feature_indices))
    
    for t in 1:num_classifiers
        # normalize the weights $w_{t,i}\gets \frac{w_{t,i}}{\sum_{j=1}^n w_{t,j}}$
        weights .*= inv(sum(weights))
        
        # For each feature j, train a classifier $h_j$ which is restricted to using a single feature.  The error is evaluated with respect to $w_j,\varepsilon_j = \sum_i w_i\left|h_j\left(x_i\right)-y_i\right|$
        @threads for j in 1:length(feature_indices)
            classification_errors[j] = sum(1:num_imgs) do img_idx
                labels[img_idx] !== votes[feature_indices[j], img_idx] ? weights[img_idx] : zero(Float64)
            end
        end
        
        # choose the classifier $h_t$ with the lowest error $\varepsilon_t$
        best_error, min_error_idx = findmin(classification_errors)
        best_feature_idx = feature_indices[min_error_idx]
        best_feature = features[best_feature_idx]

        # set feature weight
        best_feature = features[best_feature_idx]
        feature_weight = β(best_error)
        best_feature.weight = feature_weight

        # append selected features
        classifiers = push!(classifiers, best_feature)

        # update image weights $w_{t+1,i}=w_{t,i}\beta_{t}^{1-e_i}$
        sqrt_best_error = @fastmath(sqrt(best_error / (one(best_error) - best_error)))
        inv_sqrt_best_error = @fastmath(sqrt((one(best_error) - best_error)/best_error))
        @inbounds for i in 1:num_imgs
            if labels[i] !== votes[best_feature_idx, i]
                weights[i] *= inv_sqrt_best_error
            else
                weights[i] *= sqrt_best_error
            end
        end

        # remove feature (a feature can't be selected twice)
        filter!(e -> e ∉ best_feature_idx, feature_indices) # note: without unicode operators, `e ∉ [a, b]` is `!(e in [a, b])`
        resize!(classification_errors, length(feature_indices))
        next!(p) # increment progress bar
    end
    
    print("\n") # for a new line after the progress bar
    
    return classifiers
    
end

function learn(
    positive_path::AbstractString,
    negative_path::AbstractString,
    num_classifiers::Int64=-1,
    min_feature_width::Int64=1,
    max_feature_width::Int64=-1,
    min_feature_height::Int64=1,
    max_feature_height::Int64=-1;
    scale::Bool = false,
    scale_to::Tuple = (200, 200)
)
    
    votes, features = get_feature_votes(
        positive_path,
        negative_path,
        num_classifiers,
        min_feature_width,
        max_feature_width,
        min_feature_height,
        max_feature_height,
        scale = scale,
        scale_to = scale_to
    )
    
    return learn(positive_path, negative_path, features, votes, num_classifiers)
end

"""
    create_features(
        img_height::Integer,
        img_width::Integer,
        min_feature_width::Integer,
        max_feature_width::Integer,
        min_feature_height::Integer,
        max_feature_height::Integer
    ) -> Array{HaarLikeObject, 1}

Iteratively creates the Haar-like feautures

# Arguments

- `img_height::Integer`: The height of the image
- `img_width::Integer`: The width of the image
- `min_feature_width::Integer`: The minimum width of the feature (used for computation efficiency purposes)
- `max_feature_width::Integer`: The maximum width of the feature
- `min_feature_height::Integer`: The minimum height of the feature
- `max_feature_height::Integer`: The maximum height of the feature

# Returns

- `features::AbstractArray`: an array of Haar-like features found for an image
"""
function create_features(
    img_height::Int64,
    img_width::Int64,
    min_feature_width::Int64,
    max_feature_width::Int64,
    min_feature_height::Int64,
    max_feature_height::Int64
)
    notify_user("Creating Haar-like features...")
    features = HaarLikeObject[]
    
    if img_width < max_feature_width || img_height < max_feature_height
        error("""
        Cannot possibly find classifiers whose size is greater than the image itself [(width,height) = ($img_width,$img_height)].
        """)
    end
    
    for feature in values(feature_types) # (feature_types are just tuples)
        feature_start_width = max(min_feature_width, first(feature))
        for feature_width in feature_start_width:first(feature):(max_feature_width)
            feature_start_height = max(min_feature_height, last(feature))
            for feature_height in feature_start_height:last(feature):(max_feature_height)
                for x in 1:(img_width - feature_width)
                    for y in 1:(img_height - feature_height)
                        push!(features, HaarLikeObject(feature, (x, y), feature_width, feature_height, 0, 1))
                        push!(features, HaarLikeObject(feature, (x, y), feature_width, feature_height, 0, -1))
                    end # end for y
                end # end for x
            end # end for feature height
        end # end for feature width
    end # end for feature in feature types
    
    println("...finished processing; ", length(features), " features created.\n")
    
    return features
end
