# sersolsol
local processing for SerSol ebook MARC

This was originally a much more ambitious project than it ended up becoming. A lot of the old files/starts at more advanced features are still in the code because cleaning it out hasn't been the highest priority. 

Scripts we actually use: 
- bin/monthly_processing.rb
- bin/splitter.rb

See SerSolSol_script_workflow.pdf for our step-by-step monthly process for using the scripts. Highly local process, but hopefully gives the basic idea of how this is used. 

Assumes that there is a data directory at the same level as the bin directory, with the following structure: 
- data
-- ssmrc
--- orig
---- 2016
---- 2017
--- split_lib
--- split_load
--- split_pkg
-- mill_data.csv
-- pkg_list.csv

**mill_data.csv** = list of 001 values and locations for SerialsSolutions bibs from ILS

**pkg_list.csv** = list of known packages, specifiying for each: 
- whether MARC should be processed/loaded
- values to be added in 773$t and 506$f fields

**ssmrc** = stands for SerialsSolutions MARC, and is where MARC records are stored in a structured way so the scripts can find/write the appropriate files

**ssmrc/orig** = original (renamed) files received from SerialsSolutions -- organized in subdirectories for each year

**ssmrc/split_lib** = destination for files split by library/branch

**ssmrc/split_load** = destination for files we've processed for load into ILS and/or loaded

**ssmrc/split_pkg** = rarely used, but destination for files split out by package, when that option in monthly_processing.rb is used
