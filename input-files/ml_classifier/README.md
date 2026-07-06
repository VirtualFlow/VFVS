This folder holds the trained ML tranche-prioritization classifier (`model.pt` by default).
It is populated by running `tools/train_ml_classifier.py` once against a prescreen run's summary files.
Its contents are bundled into `vf_input.tar.gz` automatically for AWS Batch runs, the same way as the rest of `input-files/`.
See the "Machine Learning Classifier" section of `all.ctrl` and the main VFVS README for usage.
