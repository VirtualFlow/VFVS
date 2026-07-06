## VFVS - VirtualFlow for Virtual Screening



Welcome to the VirtualFlow project!

VirtualFlow ([Homepage](https://virtual-flow.org/)) is a versatile, parallel workflow platform for carrying out virtual screening related tasks on Linux-based computer clusters of any type and size which are managed by a batchsystem (such as SLURM). 

Currently, there exist two versions of VirtualFlow, which are tailored to different types of tasks:

- [VFLP: VirtualFlow for Ligand Preparation](https://github.com/VirtualFlow/VFLP)
- [VFVS : VirtualFlow for Virtual Screenings](https://github.com/VirtualFlow/VFVS)

They use the same core technology regarding the workflow management and parallelization, and they can be used individually or in concert with each other. Additional versions are expected to arrive in the future. Pre-built ready-to-dock ligand libraries for VFVS are available for free (in the download section). 


### Optional: Machine Learning Classifier for Molecule Prioritization

For ultra-large screens, VFVS supports an optional machine learning classifier that predicts which molecules within a collection are likely to be high-affinity binders, so only those molecules are docked. It is a fully-connected feedforward neural network (Morgan fingerprints in, binding probability out) trained on the docking scores from a small representative "prescreen" run. It is disabled by default and works identically on both the Slurm/HPC and AWS Batch execution paths.

1. **Prescreen.** Run the existing, unmodified VFVS workflow on a small representative set of collections, to get real docking scores in the usual per-collection summary files.
2. **Train.** From the `tools` directory, run:
   ```
   python3 train_ml_classifier.py --scenario <docking_scenario_name>
   ```
   This trains the classifier on the prescreen's summary files and saves it to the path given by `ml_classifier_model_path` in `all.ctrl` (default `ml_classifier/model.pt`, relative to `input-files/`).
3. **Primary screen.** Set `use_ml_classifier=true` in `all.ctrl` (see the "Machine Learning Classifier" section of `tools/templates/all.ctrl` for all options) and submit the primary screen as usual.

Requires PyTorch and RDKit (CPU-only PyTorch is sufficient); only needed if `use_ml_classifier=true`. See [Preparing the Workflow](docs/vfvs/using-vfvs/preparing-the-workflow.md#machine-learning-classifier-for-molecule-prioritization) for full details.


### Overview of Resources

The following gives an overview of the various resources related to VirtualFlow:

- [Homepage of VirtualFlow](https://virtual-flow.org/)
- [The documentation of VirtualFlow](https://docs.virtual-flow.org/documentation/-LdE8RH9UN4HKpckqkX3/)
- [Tutorials for VirtualFlow](https://virtual-flow.org/tutorials)
- [Feature Requests (powered by Canny)](http://feedback.virtual-flow.org/feature-requests)
- [GitHub Issue Tracker for VFVS](https://github.com/VirtualFlow/VFVS/issues)
- [GitHub Issue Tracker for VFLP](https://github.com/VirtualFlow/VFLP/issues)
- In-code documentation of the source code files


### Contributing

If you are interested in contributing to VirtualFlow, whether it is to report a bug or to extend VirtualFlow with your own code, please see the file [CONTRIBUTING.md](CONTRIBUTING.md) and the file [CODE_OF_CONDUCT.md](CODE_OF_CONDUCT.md).



### License

The project ist distributed under the GNU GPL v2.0. Please see the file [LICENSE](LICENSE) for more details. 


### Citation

The use of VirtualFlow or the VirtualFlow ligand libraries in any reports or publications should be acknowledged by including a citation to:

- Gorgulla, C., Boeszoermenyi, A., Wang, Z. et al. An open-source drug discovery platform enables ultra-large virtual screens. Nature (2020). https://doi.org/10.1038/s41586-020-2117-z


### VirtualFlow Forum

If you need help or have any questions related to VirtualFlow, please use our forum: 

* https://community.virtual-flow.org/
