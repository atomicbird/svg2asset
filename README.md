#  svg2asset - Bulk convert SVGs to an Xcode asset catalog

This command-line tool will convert one or more directories containing SVG image files to an asset catalog suitable for use in Xcode. The asset catalog contains PDF images configured with a single scale, optionally for use as template images. The tool can also use [SwiftGen](https://github.com/SwiftGen/SwiftGen) to create a source file for the images in the asset catalog, if SwiftGen is installed. 

The [Feather icon set](git@github.com:feathericons/feather.git) is included as a submodule to provide a large set of sample SVGs.

## Installing

- **Get the source**. Clone this repository. If you want to include a sample collection of SVGs, be sure to use `git clone --recursive` so that the Feather icon set will be included. If you already cloned the repo and want to add the Feather SVGs, use `git submodule update --init` to add them.
- **Install `svg2pdf`**. This tool uses `svg2pdf` (part of [Cairo](https://www.cairographics.org/)) to convert images. The easiest way to get this is with [Homebrew](https://brew.sh/). This tool will not work if `svg2pdf` is not installed.
- (optional) **Install SwiftGen**. If you have [SwiftGen](https://github.com/SwiftGen/SwiftGen), you can generate Swift source code for the asset catalog. SwiftGen can also be installed with Homebrew. 

If you included Feather, you can now run the tool from Xcode and see sample results, which will be written to `/tmp/`. If you didn't include Feather, read on for how to use the tool.

## Using

The command options are:

    svg2asset [--input-dir <dir>] [--asset-catalog <path>] [--verbose] [--force] [--swift-gen] [--serial] [--no-serial] [--template] [--no-template] [--icon-names <icon-names> ...]

Options are defined as follows:

- `-i, --input-dir <dir>` Input directory containing SVGs (default: .)
- `-a, --asset-catalog <path>` Path to output asset catalog. (default:./Assets.xcassets)
- `-t, --template/--no-template` Make image assets into template images ("Render As" will be set to "Template Image" in Xcode) (default: false)
- `-v, --verbose` Print verbose output 
- `-f, --force` Overwrite an asset catalog at the destination, if it exists. 
- `--swift-gen` Use SwiftGen to generate code for the asset catalog (if SwiftGen is installed). 
- `--icon-names <icon-names>` List of names of files to convert. If this is omitted, all icons in input-dir are converted. 
- `-h, --help` Show help information.
- `--serial/--no-serial` Require serial processing instead of concurrent. (default: false) (Normally only useful for debugging)

The default options included in the project file execute the command as follows:

    svg2asset --input-dir $(PROJECT_DIR)/feather/icons --asset-catalog /private/tmp/Feather.xcassets --template --icon-names disc.svg delete.svg image.svg home.svg --swift-gen --force -v

This means:

- Find SVGs in the Feather submodule relative to the project folder
- Create an asset catalog named `Feather.xcassets` in `/tmp/`. 
- Only convert four icons, as given by `--icon-names`, so the asset catalog contains only four images. 
- Create a Swift source file at `/tmp/Feater.swift`, since `--swift-gen` is included.
- Overwrite existing files if they exist
- Print details of what's happening while processing the images.

