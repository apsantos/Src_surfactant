!********************************************************************************
!   Cassandra - An open source atomistic Monte Carlo software package
!   developed at the University of Notre Dame.
!   http://cassandra.nd.edu
!   Prof. Edward Maginn <ed@nd.edu>
!   Copyright (2013) University of Notre Dame du Lac
!
!   This program is free software: you can redistribute it and/or modify
!   it under the terms of the GNU General Public License as published by
!   the Free Software Foundation, either version 3 of the License, or
!   (at your option) any later version.
!
!   This program is distributed in the hope that it will be useful,
!   but WITHOUT ANY WARRANTY; without even the implied warranty of
!   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
!   GNU General Public License for more details.
!
!   You should have received a copy of the GNU General Public License
!   along with this program.  If not, see <http://www.gnu.org/licenses/>.
!*******************************************************************************

MODULE File_Names

  !**********************************************************************

  ! This module assigns names to various files.
  ! 
  ! Used by 
  !
  !   angle_dist_pick
  !   atoms_to_place
  !   clean_abort
  !   create_intra_exclusion_table
  !   create_nonbond_table
  !   energy_routines
  !   fragment_growth
  !   gcmc_control
  !   gcmc_driver
  !   gemc_control
  !   gemc_driver
  !   gemc_particle_transfer
  !   grow_molecules
  !   input_routines
  !   main
  !   nptmc_control
  !   nvtmc_control
  !   nvtmc_driver
  !   nvt_mc_fragment_driver
  !   participation
  !   precalculate
  !   random_generators
  !   read_write_checkpoint
  !   rigid_dihedral_change
  !   rotate
  !   volume_change
  !   write_properties
  !   zig_by_omega
  !
  ! Revision history: 
  !
  !   12/10/13 : Beta Release
  !
  !**********************************************************************
USE xtc_interface

INTEGER, PARAMETER :: FILENAME_LEN = 240

!Variables to hold unit number and filename for the input file
INTEGER :: inputunit = 5
CHARACTER(FILENAME_LEN) :: inputfile
CHARACTER(8) :: testname

!Variables to hold unit number and filename for the log file
INTEGER, PARAMETER :: logunit = 25
CHARACTER(FILENAME_LEN) :: logfile

! Name of the files that contain connectivity information for 
! each species.
INTEGER :: molfile_unit = 15
CHARACTER(FILENAME_LEN), DIMENSION(:), ALLOCATABLE :: molfile_name

! Name of the file that has the cross interaction terms for all atoms in all species.
INTEGER :: mixfile_unit = 16
CHARACTER(FILENAME_LEN) :: mixfile_name

! Name of the file that has the intra scaling values for specific types.
INTEGER :: intrafile_unit = 17
CHARACTER(FILENAME_LEN), DIMENSION(:), ALLOCATABLE :: intrafile_name

!Variables to hold unit number and filename for the crash file
INTEGER :: crashunit = 30
CHARACTER(FILENAME_LEN) :: crashfile

!Variables to hold unit number and filename for a snapshot file
INTEGER :: snapunit = 35
CHARACTER(FILENAME_LEN) :: snapfile

!Variables to hold unit number and filename for a movie file
INTEGER :: movieunit = 40
CHARACTER(FILENAME_LEN) :: moviefile

!Variables to hold unit number and filename for the data file
INTEGER :: datunit = 45
CHARACTER(FILENAME_LEN) :: datfile

INTEGER :: binunit = 55

!Variables to hold unit number and filename for the initial config file
INTEGER :: configunit = 60
CHARACTER(FILENAME_LEN) :: configfile

!Variables to hold unit number and filename for the trajectory file
INTEGER :: trajunit = 70
CHARACTER(FILENAME_LEN) :: trajfile

!Varables to hold unit the initial geometry file for species
INTEGER :: init_geomunit = 80
CHARACTER(FILENAME_LEN), DIMENSION(:), ALLOCATABLE :: init_geomfile

! Variables assoicated with the checkpoint file
INTEGER :: chkptunit = 90
CHARACTER(FILENAME_LEN) :: checkpointfile

! Variables associated with the restart file
INTEGER :: restartunit = 100
CHARACTER(FILENAME_LEN) :: restart_file

! Variables associated with properties file
! Name of the property files will have dimensions of max_nbr_properties
! determined in input_routines.f90
INTEGER :: propunit = 110
CHARACTER(FILENAME_LEN),DIMENSION(:,:),ALLOCATABLE :: prop_files
! Names of property output, dimensions of (max_nbr_properties,nbr_prop_files)
CHARACTER(FILENAME_LEN),DIMENSION(:,:,:), ALLOCATABLE :: prop_output

! Variables associated with xyz configuration file
INTEGER,DIMENSION(:),ALLOCATABLE :: xyz_config_unit
CHARACTER(FILENAME_LEN),DIMENSION(:),ALLOCATABLE :: xyz_config_file

! Variables associated with dcd configuration file
INTEGER :: dcd_config_unit
CHARACTER(FILENAME_LEN) :: dcd_config_file

! index file 
INTEGER :: ndx_unit
CHARACTER(FILENAME_LEN) :: ndx_file

! Variables associated with gro configuration file
INTEGER :: gro_config_unit
CHARACTER(FILENAME_LEN) :: gro_config_file

! Variables associated with xtc configuration file
type(xdrfile), pointer :: xtc_config_unit
CHARACTER(FILENAME_LEN) :: xtc_config_file

! Variables associated with old configuration file
INTEGER :: old_config_unit = 120
CHARACTER(FILENAME_LEN),DIMENSION(:),ALLOCATABLE :: old_config_file

! Variables associated with sorbate files
INTEGER :: sorbate_unit = 120
CHARACTER(FILENAME_LEN), DIMENSION(:), ALLOCATABLE :: sorbate_file

! Variables associated with fragment files
INTEGER :: frag_file_unit = 130
CHARACTER(FILENAME_LEN), DIMENSION(:), ALLOCATABLE :: frag_file

! Variables associated with reservoir file
INTEGER :: res_file_unit = 140
CHARACTER(FILENAME_LEN), DIMENSION(:,:), ALLOCATABLE :: res_file


! Variables associated with rdf file
! Movie file is being split in two files: one containing coordinates
! and other with the header information for each frame.
! These two files will be used together for analysis purpose
! rdfunit will be replaced with movie_unit and movie_header_unit
! INTEGER :: rdfunit = 150
! Added by NR-2008
!Variables associated with the movie file
INTEGER :: movie_header_unit = 150
INTEGER :: movie_xyz_unit = 160
INTEGER :: movie_clus_xyz_unit = 165

! Variables associated with zeolite unit cell file
INTEGER :: lattice_file_unit = 170
CHARACTER(FILENAME_LEN) :: lattice_file

! Variables associated with volume file
INTEGER :: volume_info_unit = 180
CHARACTER(FILENAME_LEN) :: volume_info_file

! Cluster distribution file
INTEGER :: cluster_file_unit = 919
CHARACTER(FILENAME_LEN) :: cluster_file

! Histogram
INTEGER :: histogram_file_unit = 600
CHARACTER(FILENAME_LEN) :: histogram_file

! Mean-squared deviation file
INTEGER :: msd_file_unit = 609
CHARACTER(FILENAME_LEN) :: msd_file

! Mean-squared deviation file
INTEGER :: vacf_file_unit = 619
CHARACTER(FILENAME_LEN) :: vacf_file

! Mean-squared deviation file
INTEGER :: dipole_file_unit = 629
CHARACTER(FILENAME_LEN) :: dipole_file

! Bond histogram file
INTEGER :: bond_file_unit = 700
CHARACTER(FILENAME_LEN) :: bond_file

! Angle histogram file
INTEGER :: angle_file_unit = 710
CHARACTER(FILENAME_LEN) :: angle_file

! Dihedral  histogram file
INTEGER :: dihedral_file_unit = 720
CHARACTER(FILENAME_LEN) :: dihedral_file

! Atom distribution histogram file
INTEGER :: a_dist_file_unit = 730
CHARACTER(FILENAME_LEN) :: a_dist_file

END MODULE File_Names
