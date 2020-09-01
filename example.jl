#!/usr/bin/env bash
    #=
    exec julia --project="~/FaceDetection.jl/" "${BASH_SOURCE[0]}" "$@" -e "include(popfirst!(ARGS))" \
    "${BASH_SOURCE[0]}" "$@"
    =#
    
    
#=
Adapted from https://github.com/Simon-Hohberg/Viola-Jones/
=#

println("\033[1;34m===>\033[0;38m\033[1;38m\tLoading required libraries (it will take a moment to precompile if it is your first time doing this)...\033[0;38m")

include("src/FaceDetection.jl")
include(joinpath("src", "FaceDetection.jl"))

using .FaceDetection
using Printf: @printf
using Images: Gray, clamp01nan, save, imresize


function main(smartChooseFeats::Bool=false, alt::Bool=false, imageReconstruction::Bool=false, featValidaton::Bool=true)
      mainPath = "/Users/jakeireland/FaceDetection.jl/"
      mainImagePath = "$mainPath/data/main/"
      altImagePath = "$mainPath/data/alt/"
      
      if alt
            posTrainingPath = "$altImagePath/pos/"
            negTrainingPath = "$altImagePath/neg/"
            posTestingPath = "$altImagePath/testing/pos/"
            negTestingPath = "/Users/jakeireland/Desktop/Assorted Personal Documents/Wallpapers copy/"
      elseif ! alt
            posTrainingPath = "$mainImagePath/trainset/faces/"
            negTrainingPath = "$mainImagePath/trainset/non-faces/"
            posTestingPath = "$mainImagePath/testset/faces/"#joinpath(homedir(), "Desktop", "faces")#"$mainImagePath/testset/faces/"
            negTestingPath = "$mainImagePath/testset/non-faces/"
      end

      numClassifiers = 10

      if ! smartChooseFeats
            # For performance reasons restricting feature size
            minFeatureHeight = 8
            maxFeatureHeight = 10
            minFeatureWidth = 8
            maxFeatureWidth = 10
      end


      FaceDetection.notifyUser("Loading faces...")
      
      facesTraining = FaceDetection.loadImages(posTrainingPath)
      facesIITraining = map(FaceDetection.toIntegralImage, facesTraining) # list(map(...))
      println("...done. ", length(facesTraining), " faces loaded.")
      
      FaceDetection.notifyUser("Loading non-faces...")
      
      nonFacesTraining = FaceDetection.loadImages(negTrainingPath)
      nonFacesIITraining = map(FaceDetection.toIntegralImage, nonFacesTraining) # list(map(...))
      println("...done. ", length(nonFacesTraining), " non-faces loaded.\n")

      # classifiers are haar like features
      classifiers = FaceDetection.learn(facesIITraining, nonFacesIITraining, numClassifiers, minFeatureHeight, maxFeatureHeight, minFeatureWidth, maxFeatureWidth)

      FaceDetection.notifyUser("Loading test faces...")
      
      facesTesting = FaceDetection.loadImages(posTestingPath)
      # facesIITesting = map(FaceDetection.toIntegralImage, facesTesting)
      facesIITesting = map(i -> imresize(i, (19,19)), map(FaceDetection.toIntegralImage, facesTesting))
      println("...done. ", length(facesTesting), " faces loaded.")
      
      FaceDetection.notifyUser("Loading test non-faces..")
      
      nonFacesTesting = FaceDetection.loadImages(negTestingPath)
      nonFacesIITesting = map(FaceDetection.toIntegralImage, nonFacesTesting)
      println("...done. ", length(nonFacesTesting), " non-faces loaded.\n")

      FaceDetection.notifyUser("Testing selected classifiers...")
      correctFaces = 0
      correctNonFaces = 0
      correctFaces = sum(FaceDetection.ensembleVoteAll(facesIITesting, classifiers))
      correctNonFaces = length(nonFacesTesting) - sum(FaceDetection.ensembleVoteAll(nonFacesIITesting, classifiers))
      correctFacesPercent = (float(correctFaces) / length(facesTesting)) * 100
      correctNonFacesPercent = (float(correctNonFaces) / length(nonFacesTesting)) * 100

      facesFrac = string(correctFaces, "/", length(facesTesting))
      facesPercent = string("(", correctFacesPercent, "% of faces were recognised as faces)")
      nonFacesFrac = string(correctNonFaces, "/", length(nonFacesTesting))
      nonFacesPercent = string("(", correctNonFacesPercent, "% of non-faces were identified as non-faces)")

      println("...done.\n")
      FaceDetection.notifyUser("Result:\n")
      
      @printf("%10.9s %10.9s %15s\n", "Faces:", facesFrac, facesPercent)
      @printf("%10.9s %10.9s %15s\n\n", "Non-faces:", nonFacesFrac, nonFacesPercent)

      if imageReconstruction
            # Just for fun: putting all Haar-like features over each other generates a face-like image
            FaceDetection.notifyUser("Constructing an image of all Haar-like Features found...")
            
            reconstructedImage = FaceDetection.reconstruct(classifiers, size(facesTesting[1]))
            save(joinpath(homedir(), "Desktop", "reconstruction.png"), Gray.(map(clamp01nan, reconstructedImage)))
            
            println("...done.  See ", joinpath(homedir(), "Desktop", "reconstruction.png"), ".\n")
      end
      
      if featValidaton
            FaceDetection.notifyUser("Constructing a validation image on a random image...")
            
            FaceDetection.generateValidationImage(FaceDetection.getRandomImage(joinpath(homedir(), "Desktop", "faces")), classifiers)
            
            println("...done.  See ", joinpath(homedir(), "Desktop", "validation.png"), ".\n")
      end
end



@time main(false, false, true, true)
