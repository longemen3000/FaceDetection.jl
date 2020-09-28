#!/usr/bin/env bash
    #=
    exec julia --project="$(realpath $(dirname $0))/" "${BASH_SOURCE[0]}" "$@" -e "include(popfirst!(ARGS))" \
    "${BASH_SOURCE[0]}" "$@"
    =#
    
    
#=
Adapted from https://github.com/Simon-Hohberg/Viola-Jones/
=#


println("\033[1;34m===>\033[0;38m\033[1;38m\tLoading required libraries (it will take a moment to precompile if it is your first time doing this)...\033[0;38m")

include(joinpath(dirname(dirname(@__FILE__)), "src", "FaceDetection.jl"))

using .FaceDetection
const FD = FaceDetection
using Printf: @printf
using Images: imresize
using Serialization: serialize

println("...done")

function main(;
    smart_choose_feats::Bool=false, alt::Bool=false
)
	include("constants.jl")

	if ! alt
		include("main_data.jl")
	else
		include("alt_data.jl")
	end

    min_size_img = (19, 19) # default for our test dataset
    if smart_choose_feats
        # For performance reasons restricting feature size
        notify_user("Selecting best feature width and height...")
        
        max_feature_width, max_feature_height, min_feature_height, min_feature_width, min_size_img = determine_feature_size(pos_training_path, neg_training_path)
        
        println("...done.  Maximum feature width selected is $max_feature_width pixels; minimum feature width is $min_feature_width; maximum feature height is $max_feature_height pixels; minimum feature height is $min_feature_height.\n")
    else
        min_feature_height = 8
        max_feature_height = 10
        min_feature_width = 8
        max_feature_width = 10
    end


    FD.notify_user("Loading faces...")

    faces_training = FD.load_images(pos_training_path)[1]
    faces_ii_training = map(FD.to_integral_image, faces_training) # list(map(...))
    println("...done. ", length(faces_training), " faces loaded.")

    FD.notify_user("Loading non-faces...")

    non_faces_training = FD.load_images(neg_training_path)[1]
    non_faces_ii_training = map(FD.to_integral_image, non_faces_training) # list(map(...))
    println("...done. ", length(non_faces_training), " non-faces loaded.\n")

    # classifiers are haar like features
    classifiers = FD.learn(faces_ii_training, non_faces_ii_training, num_classifiers, min_feature_height, max_feature_height, min_feature_width, max_feature_width)

	# write classifiers to file
	serialize(joinpath(dirname(@__FILE__), "data", "haar-like_features"), classifiers)
end

@time main(smart_choose_feats=true, alt=false)
