# Purpose
- To develop the ocean and sea ice (or, _marine_) parts of the [UFS Weather Model.](https://github.com/ufs-community/ufs-weather-model)
- The source contains only those components that are relevant to the above goal; none else.

# To clone

```
git clone --jobs 4 --recursive git@github.com:sanAkel/ufs-ocean.git
```

# To build

```
cd ufs-ocean/scripts
./compile_ufs.sh <Full path to the UFS Weather Model source code> |& tee build.log
```

- For example:
  ```
  ./compile_ufs.sh /autofs/ncrc-svm1_home1/Santha.Akella/collab-work/ufs-ocean/sorc/ufs-weather-model |& tee build.log
  ```
