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
!********************************************************************************

!********************************************************************************
MODULE Run_Variables
!********************************************************************************
 
  ! Written by: Ed Maginn
  ! Sept., 2007

  ! *** Used by ***
  ! atoms_to_place
  ! compute_cell_dimensions
  ! create_nonbond_table
  ! get_internal_coords
  ! grow_molecules
  ! input_routines
  ! io_utilities
  ! main
  ! minimum_image_separation
  ! nvtmc_control
  ! participation
  ! random_generators   ONLY : iseed
  ! save_revert_coordinates
  ! translate

  ! Revision history:
  !
  !
  ! 08/02/13 : Beta release version
  ! 03/17/15 (JS) : lactivity defined for GCMC simulations
!*********************************************************************************

USE Type_Definitions

  SAVE

!*********************************************************************************
  ! This section contains global variables used by many routines during the run.

  INTEGER, PARAMETER :: charLength = 240
  INTEGER, PARAMETER :: lineArrayLength = 80
  CHARACTER(charLength) :: run_name, start_type
  CHARACTER(charLength) :: err_msg(10)

  ! error handling variables
  INTEGER :: AllocateStatus, OpenStatus, DeAllocateStatus

  ! Timing function
  CHARACTER(15) :: hostname,date,time,zone
  INTEGER, DIMENSION(8) :: values, begin_values,end_values

  LOGICAL :: lattice_sim

  ! Type of simulation to run:
  ! Choices: NVT_MC 
  CHARACTER(20) :: sim_type
  INTEGER :: int_sim_type
  INTEGER, PARAMETER :: sim_nvt = 0
  INTEGER, PARAMETER :: sim_nvt_min = 1
  INTEGER, PARAMETER :: sim_npt = 2
  INTEGER, PARAMETER :: sim_gemc = 3
  INTEGER, PARAMETER :: sim_gcmc = 4
  INTEGER, PARAMETER :: sim_frag = 5
  INTEGER, PARAMETER :: sim_ring = 6
  INTEGER, PARAMETER :: sim_gemc_npt = 7
  INTEGER, PARAMETER :: sim_gemc_ig = 8
  INTEGER, PARAMETER :: sim_mcf = 9
  INTEGER, PARAMETER :: sim_test = 10
  INTEGER, PARAMETER :: sim_pp = 11
  INTEGER, PARAMETER :: sim_virial = 12
  LOGICAL :: lfugacity, lchempot, timed_run, openmp_flag, en_flag

  ! The starting seed for the random generator
  ! Note iseed is used for generating points on random sphere for MCF_Gen sim type.
 INTEGER (KIND=8) :: iseed, iseed1, iseed3 

  ! Variables associated with the nonbond potential
  CHARACTER(15) :: mix_rule, run_style
  CHARACTER(15), DIMENSION(:), ALLOCATABLE :: vdw_style, charge_style, vdw_sum_style, charge_sum_style
  INTEGER :: int_mix_rule, int_run_style
  INTEGER, DIMENSION(:), ALLOCATABLE :: int_vdw_style, int_vdw_sum_style
  LOGICAL, DIMENSION(:,:,:), ALLOCATABLE :: int_vdw_style_mix ! the length of the 3rd dimension is the largest vdw_type
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: int_vdw_sum_style_mix ! type i and j sum style
  LOGICAL, DIMENSION(:,:,:,:), ALLOCATABLE :: int_in_vdw_style_mix ! the length of the 3rd dimension is the largest vdw_type
  INTEGER, DIMENSION(:,:,:), ALLOCATABLE :: int_in_vdw_sum_style_mix ! type i and j sum style
  INTEGER, DIMENSION(:), ALLOCATABLE :: int_charge_style, int_charge_sum_style
  INTEGER, PARAMETER :: run_equil = 0
  INTEGER, PARAMETER :: run_prod = 1
  INTEGER, PARAMETER :: run_test = 2
  INTEGER, PARAMETER :: vdw_none = 0
  INTEGER, PARAMETER :: vdw_lj = 1
  INTEGER, PARAMETER :: vdw_cut = 2
  INTEGER, PARAMETER :: vdw_cut_shift = 3
  INTEGER, PARAMETER :: vdw_cut_tail = 4
  INTEGER, PARAMETER :: vdw_minimum = 5
  INTEGER, PARAMETER :: vdw_charmm = 6
  INTEGER, PARAMETER :: vdw_cut_switch = 7
  INTEGER, PARAMETER :: vdw_mie = 8
  INTEGER, PARAMETER :: vdw_lj124 = 9
  INTEGER, PARAMETER :: vdw_lj96 = 10
  INTEGER, PARAMETER :: vdw_hydra = 11
  INTEGER, PARAMETER :: vdw_corr = 12
  INTEGER, PARAMETER :: vdw_yukawa = 13
  INTEGER, PARAMETER :: vdw_sw = 14
  INTEGER, PARAMETER :: vdw_screen = 15


  INTEGER, PARAMETER :: charge_none = 0
  INTEGER, PARAMETER :: charge_coul = 1
  INTEGER, PARAMETER :: charge_cut = 2
  INTEGER, PARAMETER :: charge_ewald = 3
  INTEGER, PARAMETER :: charge_minimum = 4

  REAL(DP), DIMENSION(:), ALLOCATABLE :: rcut_cbmc 
  REAL(DP), DIMENSION(:), ALLOCATABLE :: rcut_vdw, rcut_coul, ron_charmm, roff_charmm, rcut_max
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: rcut_vdw_mix, rcut_vdwsq_mix
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: rcut_in_vdw_mix, rcut_in_vdwsq_mix
  REAL(DP), DIMENSION(:), ALLOCATABLE :: ron_switch, roff_switch, roff_switch_sq, switch_factor1
  REAL(DP), DIMENSION(:), ALLOCATABLE :: switch_factor2, ron_switch_sq
  REAL(DP), DIMENSION(:), ALLOCATABLE :: rcut_vdwsq, rcut_coulsq, ron_charmmsq, roff_charmmsq
  REAL(DP), DIMENSION(:), ALLOCATABLE :: rcut9, rcut6, rcut3
  REAL(DP), DIMENSION(:), ALLOCATABLE :: rcut_vdw3, rcut_vdw6
  REAL(DP) :: edens_cut, rcut_clus, rcut_low, rcut_lowsq
  LOGICAL, DIMENSION(:), ALLOCATABLE :: l_half_len_cutoff

 ! Mixing Rules variables :
  CHARACTER(40), DIMENSION(:,:), ALLOCATABLE :: vdw_interaction_table
  INTEGER, DIMENSION(:,:), ALLOCATABLE ::vdw_int_table
  ! LJ
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param1_table, vdw_param2_table
  ! HYDR
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param3_table, vdw_param4_table, vdw_param5_table
  ! QQ CORR
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param6_table, vdw_param7_table
  ! Yukawa
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param8_table, vdw_param9_table
  ! Square-Well potential
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param10_table, vdw_param11_table
  ! Yukawa Screened electrostatics
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: vdw_param12_table, vdw_param13_table

  REAL(DP), DIMENSION(:), ALLOCATABLE :: alpha_ewald, h_ewald_cut
  REAL(DP), DIMENSION(:), ALLOCATABLE :: alphal_ewald
  REAL(DP), DIMENSION(:), ALLOCATABLE :: ewald_p_sqrt, ewald_p
  
 
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: nint_beads
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: nexclude_beads

  ! Intramolecular exclusion variables (1-2, 1-3, 1-4 exclusions/scaling)
  ! and the scaling to use for all other intramolecular terms.
  REAL(DP), DIMENSION(:), ALLOCATABLE :: scale_1_2_vdw, scale_1_3_vdw, scale_1_4_vdw, scale_1_N_vdw
  REAL(DP), DIMENSION(:), ALLOCATABLE :: scale_1_2_charge, scale_1_3_charge, scale_1_4_charge, scale_1_N_charge

  ! Dimensions (maxatomtype,maxatomtype,nspecies)
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_intra_scale, charge_intra_scale
  LOGICAL, DIMENSION(:,:,:), ALLOCATABLE :: l_bonded

  ! LJ
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param1_table, vdw_in_param2_table
  ! HYDR
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param3_table, vdw_in_param4_table, vdw_in_param5_table
  ! QQ CORR
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param6_table, vdw_in_param7_table
  ! Yukawa
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param8_table, vdw_in_param9_table
  ! Square-Well potential
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param10_table, vdw_in_param11_table
  ! Yukawa Screened electrostatics
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: vdw_in_param12_table, vdw_in_param13_table

  ! Gromacs file parameters
  INTEGER, DIMENSION(:), ALLOCATABLE :: ndx_type

  ! How many simulation boxes we have. 
  INTEGER :: nbr_boxes
  INTEGER, PARAMETER :: int_cubic = 0
  INTEGER, PARAMETER :: int_ortho = 1
  INTEGER, PARAMETER :: int_cell = 2

! Atom placement variables

  ! Univ vectors pointing to 6,18,26, and 50 uniform points.
  REAL(DP), DIMENSION(3,50) :: sphere_vec

  ! Imsl

  INTEGER, PARAMETER :: irule = 3
  
 !***************************************************************
  !Conversion factors and constants

  REAL(DP), PARAMETER :: PI = 3.1415926536_DP
  REAL(DP), PARAMETER :: twoPI = 6.2831853072_DP
  REAL(DP), PARAMETER :: sqrtTwoPI = 2.50662827463_DP
  REAL(DP), PARAMETER :: rootPI = 1.7724538509_DP

  !lj parameters
  REAL(DP), PARAMETER :: lj126pre = 4.0_DP
  REAL(DP), PARAMETER :: lj124pre = 2.5980762114_DP
  REAL(DP), PARAMETER :: lj96pre = 6.75_DP

  !KBOLTZ is Boltzmann's constant in atomic units amu A^2 / (K ps^2)
  REAL(DP), PARAMETER :: kboltz = 0.8314472_DP

  !H_PLANK is Plank's constant in atomic units amu A^2 / ps^3
  REAL(DP), PARAMETER :: h_plank = 39.9031268605_DP

  ! The value of the fundamental electron charge squared and divided by
  ! 4*pi*epsilon0, where epsilon0 is the vacuum permittivity.  This value
  ! alllows a coulombic potential of the form (qi*qj/rij) to be used.  The
  ! full form is (qi*qj*e^2/(4*pi*epsilon0*rij)).  To simplify, the extra
  ! constant terms are subsumed into the single constant described above.
  ! The units of charge factor are:   amu A^3 / ps^2
  REAL(DP), PARAMETER :: charge_factor_vacuum = 138935.4558_DP
  REAL(DP), DIMENSION(:), ALLOCATABLE :: charge_factor
  REAL(DP), DIMENSION(:), ALLOCATABLE :: static_perm

  !Factor to convert atomic pressure (amu / (A ps^2) ) to bar
  REAL(DP), PARAMETER :: atomic_to_bar = 166.054_DP

  !Factor to convert atomic energy (amu A^2/ ps^2) to kJ/mol
  REAL(DP), PARAMETER :: atomic_to_kJmol = 0.01_DP

  !Factor to conver atomic energy to K
  REAL(DP), PARAMETER :: atomic_to_K = 1.2027221933_DP

  !Factor to convert kJ/mol to atomic energy (amu A^2/ ps^2) 
  REAL(DP), PARAMETER :: kjmol_to_atomic = 100.0_DP

  !Factor to convert energy in (eV) to atomic energy (amu A^2/ps^2)
  REAL(DP), PARAMETER :: eV_to_atomic = 9648.53082148_DP

  !Factor to convert energy in kJ/mol to kcal/mol
  REAL(DP), PARAMETER :: kJmol_to_kcalmol = 0.239005736_DP

  ! small number for comparison
  REAL(DP), PARAMETER :: tiny_number = 0.0000001_DP

  ! converstion for ideal pressure
  REAL(DP), PARAMETER :: p_const = 138.06505

  ! Upper limit to prevent overflow in exp(-beta*energy)
  REAL(DP), PARAMETER :: max_kBT = 35.0_DP

  ! IMSL error bounds
  REAL(DP), PARAMETER :: errabs = 0.0_DP
  REAL(DP), PARAMETER :: errel = 1.0E-5_DP

  ! concentration conversion
  REAL(DP), PARAMETER :: navogadro = 6.022140857E23_DP !mol-1
  REAL(DP), PARAMETER :: m3_to_A3 = 1.0E30_DP !mol-1
  REAL(DP), PARAMETER :: nperA3_to_mM = 1660539.02857

  ! Parameter identifying number of trials

  INTEGER :: kappa_ins, kappa_rot, kappa_dih

  ! Parameters identifying move in Ewald calculations
  
  INTEGER, PARAMETER :: int_insertion = 0
  INTEGER, PARAMETER :: int_deletion = 1
  INTEGER, PARAMETER :: int_translation = 2
  INTEGER, PARAMETER :: int_rotation = 3
  INTEGER, PARAMETER :: int_intra = 4
  INTEGER, PARAMETER :: int_cluster = 5

  ! Parameter for species type 

  INTEGER, PARAMETER :: int_sorbate = 1
  INTEGER, PARAMETER :: int_solvent = 2

  ! Parameters for insertion type
  INTEGER, PARAMETER :: int_noinsert = -1
  INTEGER, PARAMETER :: int_random = 0
  INTEGER, PARAMETER :: int_igas = 1

  ! Parameters for dihedral and improper type

  INTEGER, PARAMETER :: int_none = 0
  INTEGER, PARAMETER :: int_opls = 1
  INTEGER, PARAMETER :: int_charmm = 2
  INTEGER, PARAMETER :: int_harmonic = 3
  INTEGER, PARAMETER :: int_cvff = 4
  INTEGER, PARAMETER :: int_amber = 5  
  INTEGER, PARAMETER :: int_rb = 6  

  ! Define integers for molecule type
  INTEGER, PARAMETER :: int_noexist = -1
  INTEGER, PARAMETER :: int_normal = 0
  INTEGER, PARAMETER :: int_fractional = 1
  INTEGER, PARAMETER :: int_fixed = 2

  !**********************************************************************************
  ! thermodynamic state point variables
 
  REAL(DP),DIMENSION(:),ALLOCATABLE,TARGET :: temperature, beta, pressure
  
  ! **********************************************************************************
  ! system size integers used in memory allocation.
  ! Number of species, molecules, atoms, bonds, angles, dihedrals and impropers should 
  ! be kept as independent arrays  

  INTEGER :: nspecies, nspec_insert
  INTEGER, DIMENSION(:), ALLOCATABLE :: n_igas, n_igas_update, n_igas_moves, nzovero ! integers for ideal gas reservoir
  LOGICAL :: first_res_update, igas_flag
  LOGICAL, DIMENSION(:), ALLOCATABLE :: zig_calc
  INTEGER, DIMENSION(:), ALLOCATABLE :: nmolecules, natoms, nmol_start, nring_atoms, nexo_atoms
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbonds, nangles
  INTEGER, DIMENSION(:), ALLOCATABLE :: ndihedrals, nimpropers
  INTEGER, DIMENSION(:), ALLOCATABLE :: nfragments, fragment_bonds

  ! array to hold the total number of molecules of each species in a given box

  INTEGER, DIMENSION(:,:), ALLOCATABLE :: nmols, nmol_actual
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: nmols_cfc

  ! array to hold ring atom ids and exo atom ids for a fragment
  ! will have (MAXVAL(natoms), nspecies) dimensions
  
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: ring_atom_ids, exo_atom_ids

  ! force field parameter numbers - set in Input_Routines.
  ! Keep track of the number of parameters each species has.

  ! number of unique atom types
  INTEGER :: nbr_atomtypes
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbeads_in, nbeads_out
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: nexclude_beads_in, nexclude_beads_out
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbeadsfrac_in

  ! number of ideal gas particles in the intermediate box
  INTEGER :: igas_num

  ! array containing name of each atom type with idex = atomtype number.
  ! It is set and allocated to size nbr_atomtypes in Create_Nonbond_Table
  CHARACTER(charLength), DIMENSION(:), ALLOCATABLE :: atom_type_list

  ! Number of parameters required for various potential functions.
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbr_bond_params, nbr_angle_params 
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbr_improper_params, nbr_vdw_params
  INTEGER, DIMENSION(:), ALLOCATABLE :: nbr_dihedral_params

  ! **********************************************************************************
  ! Basic data structures are in the form of arrays. Derived from 

  ! type classes defined in Type_Definitions.

  ! Array with dimension (nspecies)
  TYPE(Species_Class), DIMENSION(:), ALLOCATABLE, TARGET :: species_list
    
  ! Array with dimensions (nmolecules,nspecies)
  TYPE(Molecule_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: molecule_list
  TYPE(Molecule_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: molecule_list_igas

  ! Array with dimensions (coordinate index, nmolecules, nspecies)
  TYPE(Internal_Coord_Class), DIMENSION(:,:,:), ALLOCATABLE, TARGET :: internal_coord_list

  ! Array with dimension (nbonds)
  TYPE(Internal_Coord_Class_Old), DIMENSION(:), ALLOCATABLE, TARGET :: internal_coord_list_old

  ! Array with dimensions (natoms, nmolecules, nspecies)
  TYPE(Atom_Class), DIMENSION(:,:,:), ALLOCATABLE, TARGET :: atom_list
  TYPE(Atom_Class), DIMENSION(:,:,:), ALLOCATABLE, TARGET :: atom_list_igas
  ! Array with dimension (natoms,1,nspecies) Describes positions of starting gemoetry if a configuration is to be generated
  TYPE(Atom_Class), DIMENSION(:,:,:), ALLOCATABLE, TARGET :: init_list

  ! Array with dimensions (natoms, nspecies)
  TYPE(Nonbond_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: nonbond_list
  
  ! Array with dimensions (nbonds, nspecies)
  TYPE(Bond_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: bond_list
  
  ! Array with dimensions (nangles, nspecies)
  TYPE(Angle_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: angle_list
  
  ! Array with dimensions (ndihedrals, nspecies)
  TYPE(Dihedral_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: dihedral_list
  
  ! Array with dimensions (nimpropers, nspecies)
  TYPE(Improper_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: improper_list

  ! Array with dimension (MAXVAL(natoms), nspecies)
  TYPE(Bond_Participation_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: bondpart_list

  ! Array with dimension (MAXVAL(natoms), nspecies)
  TYPE(Angle_Participation_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: angle_part_list

  ! Array with dimension (MAXVAL(natoms),nspecies)
  TYPE(Dihedral_Participation_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: dihedral_part_list

  ! Array with dimension (MAXVAL(nbonds), nspecies)
  TYPE(Bond_Atoms_To_Place_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: bond_atoms_to_place_list

  ! Array with dimension (nangles, nspecies)
  TYPE(Angle_Atoms_To_Place_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: angle_atoms_to_place_list
  
  ! Array with dimension (ndihedrals, nspecies)

  TYPE(Dihedral_Atoms_To_Place_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: dihedral_atoms_to_place_list

  ! Array with box info, dimensions (nbr_boxes)
  TYPE(Box_Class), DIMENSION(:), ALLOCATABLE, TARGET :: box_list

  ! Array with fragment info, dimension (nfragments, nspecies)
  TYPE(Frag_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: frag_list

  ! Array with fragment bond info
  TYPE(Fragment_Bond_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: fragment_bond_list

  ! Array for storing coordinates of fragments
  TYPE(Frag_Coord_Class), DIMENSION(:,:,:), ALLOCATABLE, TARGET :: frag_coords

 ! Array for storing energies of fragments
  ! Dimensions of (max_config,nfrag_types)
  REAL(DP), DIMENSION(:,:), ALLOCATABLE, TARGET :: nrg_frag


  ! **********************************************************************************

  ! Linked list for open ensemble simulations, will have dimensions of (MAXVAL(nmolecules),nspecies)

  INTEGER, DIMENSION(:,:), ALLOCATABLE, TARGET :: locate

  ! Array with angle probability info with dimension (MAXVAL(nangles),nspecies)
  
  TYPE(Angle_Probability_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: ang_prob

  ! Array with bond probability info with dimension (MAXVAL(nbonds),nspecies)
  TYPE(Bond_Length_Probability_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: bond_length_prob

  ! Bond probability cutoff
  REAL(DP) :: bond_probability_cutoff

  !**********************************************************************************************************
  ! Will have dimension of nbr_boxes
  TYPE(Energy_Class), DIMENSION(:), ALLOCATABLE, TARGET :: energy, virial
  TYPE(Energy_Class), DIMENSION(:), ALLOCATABLE, TARGET :: ac_energy, ac_virial
  
  ! Will have dimension (MAXVAL(nmolecules))
  TYPE(Energy_Class), DIMENSION(:,:), ALLOCATABLE, TARGET :: energy_igas

  ! Accumulators for thermodynamic averages,

  ! will have dimensions of nbr_boxes
  REAL(DP), DIMENSION(:),ALLOCATABLE,TARGET :: ac_volume, ac_enthalpy
  ! will have dimension of (nspecies,nbr_boxes)
  REAL(DP), DIMENSION(:,:), ALLOCATABLE, TARGET :: ac_density, ac_nmols

  LOGICAL :: block_average

  ! The following variables are defined for Ewald calculations

  ! nvecs will have dimensions of nbr_boxes
  INTEGER, DIMENSION(:), ALLOCATABLE, TARGET :: nvecs

  INTEGER, PARAMETER  :: maxk = 100000
  
  ! Dimensions of (maxk, nbr_boxes)
  REAL(DP), DIMENSION(:,:), ALLOCATABLE, TARGET :: hx, hy, hz, hsq, Cn

  ! the following arrays will have dimensions of (MAXVAL(nvecs),nbr_boxes)

  REAL(DP), DIMENSION(:,:), ALLOCATABLE, TARGET :: cos_sum, sin_sum, cos_sum_old, sin_sum_old
  REAL(DP), DIMENSION(:,:), ALLOCATABLE, TARGET :: cos_sum_start, sin_sum_start

  !*********************************************************************************************************
  ! Information on trial and probabilities of trial moves

  ! Will have dimensions of (nspecies,nbr_boxes)
  TYPE(MC_Moves_Class), DIMENSION(:,:), ALLOCATABLE,TARGET :: ntrials, nsuccess, nequil_success
  ! Variables associated with regrowth trials dimensions ( MAXVAL(nfragments), nbr_species)
  INTEGER, DIMENSION(:,:), ALLOCATABLE, TARGET :: regrowth_trials, regrowth_success

  INTEGER :: nupdate


  ! Will have dimension of nbr_boxes
  INTEGER, DIMENSION(:), ALLOCATABLE, TARGET :: nvolumes, nvol_success, ivol_success, tot_trials 
  INTEGER :: nvol_update

  ! individual move probability
  REAL(DP) :: prob_trans, prob_rot, prob_torsion, prob_volume, prob_angle, prob_insertion
  REAL(DP) :: prob_deletion, prob_swap, prob_regrowth, prob_ring, prob_atom_displacement
  REAL(DP) :: prob_cluster
  REAL(DP), ALLOCATABLE :: prob_swap_boxes(:,:)
  REAL(DP), DIMENSION(:), ALLOCATABLE :: prob_rot_species
  REAL(DP), DIMENSION(:), ALLOCATABLE :: prob_swap_species
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: prob_species_ins_pair ! APS
  REAL(DP), DIMENSION(:), ALLOCATABLE :: pair_chem_potential     ! APS
  ! pair information
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: ins_species_index ! APS
  INTEGER :: n_insertable ! APS

  LOGICAL :: l_mol_frac_swap

  LOGICAL :: f_dv, f_vratio

  REAL(DP) :: omega_max, disp_max, delta_cos_max, delta_phi_max
  REAL(DP), DIMENSION(:), ALLOCATABLE, TARGET :: prob_species_trans, prob_species_rotate
  REAL(DP), DIMENSION(:), ALLOCATABLE::prob_growth_species ! dimension nspecies
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: max_disp, max_rot, max_clus_disp

  REAL(DP) :: cut_trans, cut_rot, cut_torsion, cut_volume, cut_angle, cut_insertion, cut_deletion
  REAL(DP) :: cut_swap, cut_regrowth, cut_ring, cut_atom_displacement, cut_lambda
  REAL(DP) :: cut_cluster
 
  !*********************************************************************************************************
  ! Information on the output of data

  INTEGER :: nthermo_freq, ncoord_freq, histogram_freq, ncluster_freq, n_mcsteps, n_equilsteps, this_mcstep
  INTEGER :: nexvol_freq, nalpha_freq, nalphaclus_freq, noligdist_freq 
  INTEGER :: nmsd_freq, nvacf_freq, ndipole_freq, ncluslife_freq
  INTEGER :: nbond_freq, nangle_freq, ndihedral_freq, natomdist_freq, natomenergy_freq, nendclus_freq
  INTEGER :: nvirial_freq, npotential_freq
 
  INTEGER,DIMENSION(:),ALLOCATABLE :: nbr_prop_files

  ! Number of properties per file, will have dimension of nbr_prop_files
  
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: prop_per_file
  LOGICAL, DIMENSION(:,:), ALLOCATABLE :: first_open

  LOGICAL :: cpcollect  !  logical determining if the chemical potential info is collected


  LOGICAL :: cbmc_flag, del_flag, phi_Flag, angle_Flag, imp_Flag

  ! Some variables for reaction Monte Carlo
  LOGICAL, DIMENSION(:), ALLOCATABLE :: has_charge
  LOGICAL :: get_fragorder, l_check

  INTEGER :: imreplace = 0
  INTEGER :: isreplace = 0


!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! variables for the neighbor list
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  LOGICAL, ALLOCATABLE :: l_cubic(:)

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! timing functions
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  INTEGER :: num_moves, count_n, count_nn, count_cell

  INTEGER, PARAMETER :: imove_trans = 0
  INTEGER, PARAMETER :: imove_rot = 1
  INTEGER, PARAMETER :: imove_dihedral = 2
  INTEGER, PARAMETER :: imove_angle = 3
  INTEGER, PARAMETER :: imove_volume = 4
  INTEGER, PARAMETER :: imove_insert = 5
  INTEGER, PARAMETER :: imove_swap = 6
  INTEGER, PARAMETER :: imove_delete = 7
  INTEGER, PARAMETER :: imove_regrowth = 8
  INTEGER, PARAMETER :: imove_check = 9
  INTEGER, PARAMETER :: imove_atom_displacement = 10
  INTEGER, PARAMETER :: imove_translate_cluster = 11


  REAL(DP) :: time_s, time_e
  REAL(DP) :: start_time, tot_time
  REAL(DP), DIMENSION(0:14)  :: movetime

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: W_tensor_charge
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: W_tensor_recip
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: W_tensor_vdw
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: W_tensor_total
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: W_tensor_elec
  REAL(DP), DIMENSION(:,:,:), ALLOCATABLE :: Pressure_tensor

  REAL(DP), DIMENSION(:), ALLOCATABLE :: P_inst
  REAL(DP), DIMENSION(:), ALLOCATABLE :: P_ideal

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
! Energy check
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

  LOGICAL :: echeck_flag
  INTEGER :: iecheck

!!!!! Pair energy arrays. These arrays hold interaction energies between pairs of molecules !!!!!

  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: pair_nrg_vdw, pair_nrg_qq
  REAL(DP) :: copy_time, recip_time

  ! cos_mol and sin_mol arrays hold k space vectors for each molecule
  ! dimensions == (SUM(nmolecules), MAX(nvecs))
  REAL(DP), ALLOCATABLE :: cos_mol(:,:) , sin_mol(:,:)
  LOGICAL :: l_pair_nrg

  INTEGER :: reject_type ! a negative number for the reason the move was rejected

  REAL(DP) pacc, paccbiased, freev
  REAL(DP), DIMENSION(:,:), ALLOCATABLE :: chpot, chpotid

!!!!! Mie potential variables
  INTEGER, DIMENSION(:,:), ALLOCATABLE :: mie_Matrix
  REAL(DP), DIMENSION(:), ALLOCATABLE :: mie_nlist, mie_mlist


!!!! Zeolite variables
REAL(DP), ALLOCATABLE, DIMENSION(:) :: x_lat, y_lat, z_lat
INTEGER :: n_lat_atoms

!!!!de Broglie of pair
LOGICAL :: store_sum
  
! histogram writing variables
INTEGER(8)            :: n_energy_hist      ! number of points for energy discretization
REAL(DP)              :: energy_hist_width  ! width of energy histograms; should take into account interactions
REAL(SP), ALLOCATABLE :: energy_hist(:,:,:) ! element 0 of this matrix contains the
                                            ! starting value of energy for the bins at that amph. number. 
                                            ! element -2 is the min value of energy for non-zero observations
                                            ! element -1 is the max value of energy for non-zero observations
                                            ! this arrary takes up a LOT of memory

!*********************************************************************************************************
! Post Processing
!*********************************************************************************************************
! Information on Clusters

! Will have dimensions of (nspecies,nbr_boxes)
TYPE(Cluster_Class), TARGET :: cluster

INTEGER :: max_nmol

INTEGER, PARAMETER :: int_com = 1
INTEGER, PARAMETER :: int_type = 2
INTEGER, PARAMETER :: int_skh = 3
INTEGER, PARAMETER :: int_micelle = 4

!*********************************************************************************************************
! Information on Excluded Volume calculation

! Will have dimensions of (nspecies,nbr_boxes)
TYPE(ExVol_Class), TARGET :: exvol

! Information on Degree Association calculation
TYPE(DegreeAssociation_Class), TARGET :: alpha

TYPE(Measure_Molecules_Class), TARGET :: measure_mol

TYPE(trans_Class), TARGET :: trans

INTEGER, DIMENSION(:), ALLOCATABLE :: ia_atoms
INTEGER, DIMENSION(:), ALLOCATABLE :: im_atoms
INTEGER, DIMENSION(:), ALLOCATABLE :: is_atoms
INTEGER :: dcd_natoms, xtc_natoms, gro_natoms, xyz_natoms
LOGICAL :: read_dcd_box
TYPE(virial_Class), TARGET :: mcvirial

!*********************************************************************************************************
! Information on variable box volume

LOGICAL :: read_volume 
INTEGER :: line_nbr_vol
INTEGER :: ivolfreq

END MODULE Run_Variables

