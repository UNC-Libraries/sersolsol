# sersolsol
**local processing for SerSol ebook MARC**

## Disclaimers/caveats

The entire setup/design of this code is so specific to our library that no one else would be able to use it without major changes.

This was my very first programming project and I'd do a lot of it differently now, but there's never time to go back and rebuild from scratch.

However, this is offered here in case pieces of it are useful for other libraries that want to do some more-or-less automated processing of SerialsSolutions (or other) MARC records.

## Scope/purpose of scripts

Initial purpose for script was two-fold:
- for reasons, we would unavoidably be receiving some ebook MARC that we didn't actually want to load in our ILS. We needed to get rid of those records from the files we'd eventually process and load
- we have 3 accounting units that like to handle ebook records differently (major difference: whether item or holdings records are attached to the bibs, and the coding in those attached records), which meant we wanted to let each unit load the records for their ebook packages. But since we all use the same SerialsSolutions account, we just receive one big set of files for all of us. Needed to split the adds/deletes up per accounting unit. (Changes are loaded in a way that doesn't affect any units' idiosyncracies).

Over time, the following behavior has been added:
- Add 773 field with locally-established collection name for each package
- Add 506 field specifying number of concurrent users for each package (where the concurrent users is the same for the whole package)
- Cleaning up/fixing some invalid MARC coding or other weird little things in the MARC that SerialsSolutions has not been able/willing to fix (or that we didn't report because it's more a local issue/preference):
 - delete $c and $9 from 020
 - if the only subfields in 020 were $c and/or $9, delete the useless 020
 - Delete |9 from 044
 - Change 060 |i to |b
 - Move 088 |9 content to beginning of |a
 - Delete $y from 1XX, 240
 - Split repeated 590|a into multiple fields
 - Delete 710s for some known ebook providers
 - Delete 773s for some ebook collections (773s we didn't add!)

## Installation/Setup

- requires Ruby
- If bundler is not installed: `gem install bundler`
- clone sersolsol and install dependencies:

  ```bash
  git clone https://github.com/UNC-Libraries/sersolsol
  cd sersolsol
  bundle install
  ```

- See below for expected directory structure

## Usage

Assumes that there is a data directory at the same level as the bin directory, with the following structure:
<pre>- data
-- ssmrc
--- orig
---- 2016
---- 2017
--- split_lib
--- split_load
--- split_pkg
-- mill_data.txt
-- pkg_list.csv</pre>

**mill_data.txt** = list of bib record numbers, 001 values, and locations for SerialsSolutions bibs from ILS

**pkg_list.csv** = list of known packages, specifiying for each:
- whether MARC should be processed/loaded
- values to be added in 773$t and 506$f fields

**ssmrc** = stands for SerialsSolutions MARC, and is where MARC records are stored in a structured way so the scripts can find/write the appropriate files

**ssmrc/orig** = original (renamed) files received from SerialsSolutions -- organized in subdirectories for each year

**ssmrc/split_lib** = destination for files split by library/branch

**ssmrc/split_load** = destination for files we've processed for load into ILS and/or loaded

**ssmrc/split_pkg** = rarely used, but destination for files split out by package, when that option in monthly_processing.rb is used
