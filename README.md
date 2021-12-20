**Project Title:**

PISCES-BYONIC considers the cycling of the micronutrients cobalt, copper, manganese and zinc as nutrients in the standard p4z PISCES framework

**Papers:**

Tagliabue, A., N. J. Hawco, R. M. Bundy, W. M. Landing, A. Milne, P. L. Morton, and M. A. Saito (2018), The Role of External Inputs and Internal Cycling in Shaping the Global Ocean Cobalt Distribution: Insights From the First Cobalt Biogeochemical Model, Global Biogeochem Cycles, 32(4), 594-616, doi:10.1002/2017GB005830.

Richon, C., and A. Tagliabue (2019), Insights into the Major Processes Driving the Global Distribution of Copper in the Ocean from a Global Model, Global Biogeochemical Cycles, doi:10.1029/2019gb006280.

**Prerequisites / Getting started:**

svn: http://forge.ipsl.jussieu.fr/nemo/svn/NEMO/releases/release-4.0 r11143

Apply the below to the /cfg/ directory:

My_SRC directory
EXPREF directory (namelists, file_def, field_def and other xml files)

Example output from the +Mn limitation version of the code (ref expt BYONIC8R1) is found here:  https://doi.org/10.5281/zenodo.4781285

**Installing:**

The configuration is compiled using ./makenemo -r BYONIC

Add an annual mean ptrc file (ORCA2) so that users can explore the output of the model to compare it to their own results in case they don't get the same code version and revision.

**Authors:**

Alessandro Tagliabue

contributors:

Camille Richon
Nick Hawco

**License:**
This project is licensed under the CeCILL license (https://cecill.info/licences.en.html).

**Acknowledgments:**

Funded by ERC under the Horizons 2020 Framework - project ID: BYONIC
