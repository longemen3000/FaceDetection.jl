<h1 align="center">
   FaceDetection using Viola-Jones' Robust Algorithm for Object Detection
</h1>

[![Code Style: Blue][code-style-img]][code-style-url] [![Build Status](https://travis-ci.com/jakewilliami/FaceDetection.jl.svg?branch=master)](https://travis-ci.com/jakewilliami/FaceDetection.jl) ![Project Status](https://img.shields.io/badge/status-maturing-green)

## Introduction

This is a Julia implementation of [Viola-Jones' Object Detection algorithm](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.10.6807).  Although there is an [OpenCV port in Julia](https://github.com/JuliaOpenCV/OpenCV.jl), it seems to be ill-maintained.  As this algorithm was created for commercial use, there seem to be few widely-used or well-documented implementations of it on GitHub.  The implementation this repository is based off is [Simon Hohberg's Pythonic repository](https://github.com/Simon-Hohberg/Viola-Jones), as it seems to be well written (and the most starred Python implementation on GitHub, though this is not necessarily a good measure). Julia and Python alike are easy to read and write in &mdash; my thinking was that this would be easy enough to replicate in Julia, except for Pythonic classes, where I would have to use `struct`s (or at least easier to replicate from than, for example, [C++](https://github.com/alexdemartos/ViolaAndJones) or [JS](https://github.com/foo123/HAAR.js) &mdash; two other highly-starred repositories.).

I *implore* collaboration.  I am an undergraduate student with no formal education in computer science (or computer vision of any form for that matter); there is a chance that I have done something incorrect, and I am certain this code can be refined/optimised by better programmers than myself.  Please, help me out if you like!

## How it works

In an over-simplified manner, the Viola-Jones algorithm has some four stages:

 1. Takes an image, converts it into an array of intensity values (i.e., in grey-scale), and constructs an [Integral Image](https://en.wikipedia.org/wiki/Summed-area_table), such that for every element in the array, the Integral Image element is the sum of all elements above and to the left of it.  This makes calculations easier for step 2.
 2. Finds [Haar-like Features](https://en.wikipedia.org/wiki/Haar-like_feature) from Integral Image.
 3. There is now a training phase using sets of faces and non-faces.  This phase uses something called Adaboost (short for Adaptive Boosting).  Boosting is one method of Ensemble Learning. There are other Ensemble Learning methods like Bagging, Stacking, &c.. The differences between Bagging, Boosting, Stacking are:
      - Bagging uses equal weight voting. Trains each model with a random drawn subset of training set.
      - Boosting trains each new model instance to emphasize the training instances that previous models mis-classified. Has better accuracy comparing to bagging, but also tends to overfit.
      - Stacking trains a learning algorithm to combine the predictions of several other learning algorithms.
  Despite this method being developed at the start of the century, it is blazingly fast compared to some machine learning algorithms, and still widely used.
 4. Finally, this algorithm uses [Cascading Classifiers](https://en.wikipedia.org/wiki/Cascading_classifiers) to identify faces.  (See page 12 of the original paper for the specific cascade).
 
For a better explanation, read [the paper from 2001](http://citeseerx.ist.psu.edu/viewdoc/summary?doi=10.1.1.10.6807), or see [the Wikipedia page](https://en.wikipedia.org/wiki/Viola%E2%80%93Jones_object_detection_framework) on this algorithm.

## Running the Algorithm

```julia
using FaceDetection, Serialization # Serialization is so that you can save your results

num_classifiers = 10 # this is the number of Haar-like features you want to select

# provide paths to directories of training images
pos_training_path = "..." # positive images are, for example, faces
neg_training_path = "..." # negative images are, for example, non-faces.  However, the Viola-Jones algorithm is for object detection, not just for face detection

max_feature_width, max_feature_height, min_feature_height, min_feature_width, min_size_img = (1, 2, 3, 4) # or use the function to select reasonable sized feature parameters given your maximum image size (see below)
determine_feature_size(pos_training_path, neg_training_path)

# learn the features from
classifiers = learn(pos_training_path, neg_training_path, num_classifiers, min_feature_height, max_feature_height, min_feature_width, max_feature_width)

# provide paths to directories of testing images
pos_testing_path = "..."
neg_testing_path = "..."

# obtain results
num_faces, num_non_faces = length(filtered_ls(pos_testing_path)), length(filtered_ls(neg_testing_path));
correct_faces = sum(ensemble_vote_all(pos_testing_path, classifiers));
correct_non_faces = num_non_faces - sum(ensemble_vote_all(neg_testing_path, classifiers));
correct_faces_percent = (correct_faces / num_faces) * 100;
correct_non_faces_percent = (correct_non_faces / num_non_faces) * 100;

# print results
println("$(string(correct_faces, "/", num_faces)) ($(correct_faces_percent) %) of positive images were correctly identified.")
println("$(string(correct_non_faces, "/", num_non_faces)) ($(correct_non_faces_percent) %) of positive images were correctly identified.")
```

Alternatively, you can save the data stored by the training process and read from that data file:
```julia
using FaceDetection, Serialization # Serialization is so that you can save your results

num_classifiers = 10 # this is the number of Haar-like features you want to select

# provide paths to directories of training images
pos_training_path = "..." # positive images are, for example, faces
neg_training_path = "..." # negative images are, for example, non-faces.  However, the Viola-Jones algorithm is for object detection, not just for face detection

max_feature_width, max_feature_height, min_feature_height, min_feature_width, min_size_img = (1, 2, 3, 4) # or use the function to select reasonable sized feature parameters given your maximum image size (see below)
determine_feature_size(pos_training_path, neg_training_path)

votes, features = get_feature_votes(pos_training_path, neg_training_path, num_classifiers, min_feature_height, max_feature_height, min_feature_width, max_feature_width)

data_file = "..." # this is where you want to save your data
serialize(data_file, (votes, features)); # write classifiers to file

votes, all_features = deserialize(data_file); # read from saved data
classifiers = learn(pos_training_path, neg_training_path, all_features, votes, num_classifiers)

# provide paths to directories of testing images
pos_testing_path = "..."
neg_testing_path = "..."

# obtain results
num_faces, num_non_faces = length(filtered_ls(pos_testing_path)), length(filtered_ls(neg_testing_path));
correct_faces = sum(ensemble_vote_all(pos_testing_path, classifiers));
correct_non_faces = num_non_faces - sum(ensemble_vote_all(neg_testing_path, classifiers));
correct_faces_percent = (correct_faces / num_faces) * 100;
correct_non_faces_percent = (correct_non_faces / num_non_faces) * 100;

# print results
println("$(string(correct_faces, "/", num_faces)) ($(correct_faces_percent) %) of positive images were correctly identified.")
println("$(string(correct_non_faces, "/", num_non_faces)) ($(correct_non_faces_percent) %) of positive images were correctly identified.")
```

## Benchmarking Results

The following are benchmarking results from running equivalent programmes in both repositories.  These programmes uses ~10 thousand training images at 19 x 19 pixels each.

Language of Implementation | Commit | Run Time in Seconds | Number of Allocations | Memory Usage
--- | --- | --- | --- | ---
[Python](https://github.com/Simon-Hohberg/Viola-Jones/) | [8772a28](https://github.com/Simon-Hohberg/Viola-Jones/commit/8772a28) | 480.0354 | &mdash; <sup>*a*</sup> | &mdash; <sup>*a*</sup>
[Julia](https://github.com/jakewilliami/FaceDetection.jl/) | [6fd8ca9e](https://github.com/Simon-Hohberg/Viola-Jones/commit/6fd8ca9e) |19.9057 | 255600105 | 5.11 GiB

<sup>*a*</sup> I have not yet figured out benchmarking memory usage in Python.
 
 ## Caveats
 
  -  **Needs peer review for algorithmic correctness.**
  - In the current implementation of the Viola-Jones algorithm, we have not implemented scaling features.  This means that you should ideally have your training set the same size as your test set.  To make this easier while we work on scaling features, we have implemented keyword arguments to the functions `determine_feature_size` and `learn`.  E.g.,
 ```julia
 julia> load_image(image_path, scale = true, scale_up = (200, 200))

 julia> determine_feature_size(pos_training_path, neg_training_path; scale = true, scale_to = (200, 200))

 julia> classifiers = learn(pos_training_path, neg_training_path, num_classifiers, min_feature_height, max_feature_height, min_feature_width, max_feature_width; scale = true, scale_to = (200, 200))

 julia> ensemble_vote_all(pos_testing_path, classifiers, scale = true, scale_to = (200, 200))
 ```

## Face detection resources/datasets
```
# datasets
https://github.com/INVASIS/Viola-Jones/ # main training dataset
https://github.com/OlegTheCat/face-detection-data # alt training dataset
http://cbcl.mit.edu/projects/cbcl/software-datasets/faces.tar.gz # MIT dataset
http://tamaraberg.com/faceDataset/originalPics.tar.gz # FDDB dataset
http://vis-www.cs.umass.edu/lfw/lfw.tgz # LFW dataset
https://github.com/opencv/opencv/ # pre-trained models exist here
https://github.com/jian667/face-dataset

# resources
https://github.com/betars/Face-Resources
https://www.wikiwand.com/en/List_of_datasets_for_machine-learning_research#/Object_detection_and_recognition
https://www.wikiwand.com/en/List_of_datasets_for_machine-learning_research#/Other_images
https://www.face-rec.org/databases/
https://github.com/polarisZhao/awesome-face#-datasets
```

## Miscellaneous Notes

### Timeline of Progression

 - [a79ab6f9](https://github.com/jakewilliami/FaceDetection.jl/commit/a79ab6f9) &mdash; Began working on the algorithm; mainly figuring out best way to go about this implementation.
 - [fd5e645c](https://github.com/jakewilliami/FaceDetection.jl/commit/fd5e645c) &mdash; First "Julia" adaptation of the algorithm; still a *lot* of bugs to figure out.
 - [2fcae630](https://github.com/jakewilliami/FaceDetection.jl/commit/2fcae630) &mdash; Started bug fixing using `src/FDA.jl` (the main example file).
 - [f1f5b5ea](https://github.com/jakewilliami/FaceDetection.jl/commit/f1f5b5ea) &mdash; Getting along very well with bug fixing (created a `struct` for Haar-like feature; updated weighting calculations; fixed `hstack` translation with nested arrays).  Added detailed comments on each function.
 - [a9e10eb4](https://github.com/jakewilliami/FaceDetection.jl/commit/a9e10eb4) &mdash; First working draft of the algorithm (without image reconstruction)!
 - [6b35f6d5](https://github.com/jakewilliami/FaceDetection.jl/commit/6b35f6d5) &mdash; Finally, the algorithm works as it should.  Just enhancements from here on out.
 - [854bba32](https://github.com/jakewilliami/FaceDetection.jl/commit/854bba32) and [655e0e14](https://github.com/jakewilliami/FaceDetection.jl/commit/655e0e14) &mdash; Implemented facelike scoring and wrote score data to CSV (see [#7](https://github.com/jakewilliami/FaceDetection.jl/issues/7)).
 - [e7295f8d](https://github.com/jakewilliami/FaceDetection.jl/commit/e7295f8d) &mdash; Implemented writing training data to file and reading from that data to save computation time.
 - [e9116987](https://github.com/jakewilliami/FaceDetection.jl/commit/e9116987) &mdash; Changed to sequential processing.
 - [750aa22d](https://github.com/jakewilliami/FaceDetection.jl/commit/750aa22d)&ndash;[b3aec6b8](https://github.com/jakewilliami/FaceDetection.jl/commit/b3aec6b8) &mdash; Optimised performance.
 []() &mdash;

### Acknowledgements

Thank you to:

 - [**Simon Honberg**](https://github.com/Simon-Hohberg) for the original open-source Python code upon which this repository is largely based.  This has provided me with an easy-to-read and clear foundation for the Julia implementation of this algorithm;
 - [**Michael Jones**](https://www.merl.com/people/mjones) for (along with [Tirta Susilo](https://people.wgtn.ac.nz/tirta.susilo)) suggesting the method for a *facelike-ness* measure;
 - [**Mahdi Rezaei**](https://environment.leeds.ac.uk/staff/9408/dr-mahdi-rezaei) for helping me understand the full process of Viola-Jones' object detection;
 - [**Ying Bi**](https://ecs.wgtn.ac.nz/Main/GradYingBi) for always being happy to answer questions (which mainly turned out to be a lack of programming knowledge rather than conceptual; also with help from [**Bing Xue**](https://homepages.ecs.vuw.ac.nz/~xuebing/index.html));
 - **Mr. H. Lockwood** and **Mr. D. Peck** are Comp. Sci. students who have answered a few questions of mine;
 - Finally, the people in the Julia slack channel, for dealing with many (probably stupid) questions.  Just a few who come to mind: Micket, David Sanders, Eric Forgy, Jakob Nissen, and Roel.

### A Note on running on BSD:

The default JuliaPlots backend `GR` does not provide binaries for FreeBSD.  [Here's how you can build it from source.](https://github.com/jheinen/GR.jl/issues/268#issuecomment-584389111).  That said, `StatsPlots` is only a dependency for an example, and not for the main package.


[code-style-img]: https://img.shields.io/badge/code%20style-blue-4495d1.svg
[code-style-url]: https://github.com/invenia/BlueStyle
