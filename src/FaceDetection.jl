#!/usr/bin/env bash
    #=
    exec julia --project="$(realpath $(dirname $0))/../" "${BASH_SOURCE[0]}" "$@" -e 'include(popfirst!(ARGS))' \
    "${BASH_SOURCE[0]}" "$@"
    =#
    
module FaceDetection

export toIntegralImage, sumRegion, FeatureTypes, HaarLikeObject, getScore, getVote, learn, _create_features, displaymatrix, notifyUser, loadImages, getImageMatrix, ensembleVote, ensembleVoteAll, reconstruct, getRandomImage, generateValidationImage, getFaceness

include("IntegralImage.jl")
include("HaarLikeFeature.jl")
include("AdaBoost.jl")
include("Utils.jl")

using .IntegralImage: toIntegralImage, sumRegion
using .HaarLikeFeature: FeatureTypes, HaarLikeObject, getScore, getVote
using .AdaBoost: learn, _create_features
using .Utils: displaymatrix, notifyUser, loadImages, getImageMatrix, ensembleVote, ensembleVoteAll, getFaceness, reconstruct, getRandomImage, generateValidationImage

end # end module
