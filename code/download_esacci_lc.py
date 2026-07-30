import cdsapi
import zipfile
import os
import netCDF4

client = cdsapi.Client()
request = {
    "variable": "all",
    "year": ["2022"],
    "version": ["v2_1_1"],
    "data_format": "netcdf",
}

dst_path = '/tmp/ESACCI-LC-L4-LCCS-Map-300m-P1Y-2022-v2.1.1.zip'

try:
  client.retrieve("satellite-land-cover", request).download(dst_path)

  if zipfile.is_zipfile(dst_path):
    extract_dir = os.path.splitext(dst_path)[0]  # e.g. "era5"
    with zipfile.ZipFile(dst_path, 'r') as zip_ref:
      zip_ref.extractall(extract_dir)
    # Find the first .nc file inside
    for f in os.listdir(extract_dir):
      if f.endswith('.nc'):
        nc_path = os.path.join(extract_dir, f)
        ds = netCDF4.Dataset(nc_path, 'r')
        print(ds)
        break
      else:
        ds = netCDF4.Dataset(dst_path, 'r')
        print(ds)
      
except Exception as e:
  print("GDA Evapotranspiration processor failed due to: ", e)
  raise
  

      
