cwlVersion: v1.2

# Insula Application Package (OGC API - Processes).
#
# Rules enforced by the platform:
#   - $graph must hold EXACTLY ONE Workflow and ONE CommandLineTool.
#   - The Workflow has a single step whose `run` points at the CommandLineTool id.
#   - DockerRequirement.dockerPull is REQUIRED. The value __IMAGE__ is replaced by
#     the build pipeline with the published image reference; do not edit it.
#   - Input types: Directory = a STAC catalogue, File = a downloadable file,
#     plus string / int / long / float / boolean / enum. Outputs must be
#     File or Directory.
#   - Put each input's label/doc on the CommandLineTool input (below): that is
#     where the platform reads the user-facing parameter metadata.
#
# Replace the single example `input` / `output` with the real parameters of your
# processor, keeping the Workflow and CommandLineTool sides in sync.
$graph:
- class: Workflow
  id: gdaevapotranspiration-earthcode
  label: GDAEvapotranspiration_EarthCode
  doc: The processor estimates Daily Evapotranspiration from Sentinel-2 and Sentinel-3 morning acquisition(s) based on the Two-Source Energy Balance Algorithm (TSEB) and machine learning sharpened Land Surface Temperature, utilizing Sen-ET project as baseline.
  inputs:
    s2_input:
      label: Sentinel-2 acquisition
      doc: Sentinel-2 acquisition covering the area of interest.
      type: Directory
    s3_input:
      label: Sentinel-3 morning acquisition(s) (5-12am)
      doc: Sentinel-3 morning acquisition(s) (5-12am) covering the same area and having an acquisition date within +- 5 days from Sentinel-2 acquisition.
      type: Directory
    path_to_credentials:
      label: Path to CDSAPI credentials stored in JSON file
      doc: Credentials to CDSAPI needed to download ERA5 data.
      type: String
  outputs:
    output_daily_et:
      type: Directory
      outputSource: process/output_daily_et
    output_lst:
      type: Directory
      outputSource: process/output_lst
    output_s2_quality:
      type: Directory
      outputSource: process/output_s2_quality
    output_s3_quality:
      type: Directory
      outputSource: process/output_s3_quality
  steps:
    process:
      run: '#main'
      in:
        s2_input: s2_input
        s3_input: s3_input
        path_to_credentials: path_to_credentials
      out:
        - output_daily_et
        - output_lst
        - output_s2_quality
        - output_s3_quality

- class: CommandLineTool
  id: main
  requirements:
    DockerRequirement:
      dockerPull: __IMAGE__
    # Runtime network egress is OFF by default. Set to true ONLY if your processor
    # must reach the network while it runs (most batch EO processors do not).
    NetworkAccess:
      networkAccess: false
  # PLACEHOLDER - replace with the exact ENTRYPOINT/command your Dockerfile runs.
  baseCommand: /home/worker/processor/workflow.sh
  inputs:
    s2_input:
      label: Sentinel-2 acquisition
      doc: Sentinel-2 acquisition covering the area of interest.
      type: Directory
      inputBinding:
        position: 1
        prefix: --s2_input
      
    s3_input:
      label: Sentinel-3 morning acquisition(s) (5-12am)
      doc: Sentinel-3 morning acquisition(s) (5-12am) covering the same area and having an acquisition date within +- 5 days from Sentinel-2 acquisition.
      type: 
        type: array
        items: Directory
        inputBinding:
          prefix: --s3_input
          separate: false
      inputBinding:
        position: 2
        
    path_to_credentials:
      label: Path to CDSAPI credentials stored in JSON file
      doc: Credentials to CDSAPI needed to download ERA5 data.
      type: String
      inputBinding:
        position: 3
        prefix: --path_to_credentials

  outputs:
    output_daily_et:
      type: Directory
      outputBinding:
        glob: ./outDir/output_daily_et/
    output_lst:
      type: Directory
      outputBinding:
        glob: ./outDir/output_lst/
    output_s2_quality:
      type: Directory
      outputBinding:
        glob: ./outDir/output_s2_quality/
    output_s3_quality:
      type: Directory
      outputBinding:
        glob: ./outDir/output_s3_quality/

$namespaces:
  s: https://schema.org/
s:softwareVersion: 1.0.0
s:keywords: earth-observation, evapotranspiration, sentinel2, sentinel3, TSEB, sharpened_LST, SenET
$schemas:
- http://schema.org/version/latest/schemaorg-current-http.rdf
