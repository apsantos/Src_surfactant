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

MODULE Read_Write_Checkpoint
  !************************************************************************
  ! The module contains two subroutines
  ! Read a check point file when a simulation is restarted from a checkpoint file
  ! Writes this checkpoint file periodically in a simulation.
  ! Note that any changes made in generating a checkpoint must mirror changes
  ! in the reading subroutine. This will be the case when additional information
  ! is written for various ensembles.
  !
  ! Revision History: 
  ! 12/10/13  :: Beta version 
  !**************************************************************************
  USE Run_Variables
  USE File_Names
  USE Simulation_Properties
  USE Random_Generators, ONLY : s1,s2,s3,s4,s5, rranf
  USE Energy_Routines, ONLY : Compute_Molecule_Energy
  USE IO_Utilities
  
  IMPLICIT NONE

CONTAINS

  SUBROUTINE Write_Checkpoint(this_mc_step)

    INTEGER, INTENT(IN) :: this_mc_step

    INTEGER :: ibox, is, ii, jj, im, this_im, ia, nmolecules_is, this_box
    INTEGER :: total_molecules_is, this_unit
    
    LOGICAL :: lopen

    INQUIRE(file=checkpointfile,opened=lopen)
    IF (lopen) INQUIRE(file=checkpointfile, number = this_unit)
    IF (lopen) CLOSE(unit=this_unit)

    OPEN(unit=chkptunit,file=checkpointfile)
    ! Let us write all the counters

    WRITE(chkptunit,'(A)') '********* Translation,rotation, dihedral, angle distortion ******'

    DO ibox = 1, nbr_boxes
       DO is = 1, nspecies
          WRITE(chkptunit,'(5(I10,1x))') is, ntrials(is,ibox)%displacement, &
               ntrials(is,ibox)%rotation, ntrials(is,ibox)%dihedral, &
               ntrials(is,ibox)%angle
          WRITE(chkptunit,'(5(I10,1x))') is, nsuccess(is,ibox)%displacement, &
               nsuccess(is,ibox)%rotation, nsuccess(is,ibox)%dihedral, &
               nsuccess(is,ibox)%angle
          WRITE(chkptunit,'(3(E24.15))') max_disp(is,ibox), max_rot(is,ibox), &
               species_list(is)%max_torsion
          
       END DO

       IF (int_sim_type == sim_npt .OR. int_sim_type == sim_gemc .OR. &
            int_sim_type == sim_gemc_npt) THEN
          WRITE(chkptunit,'(I10,1x,I10)') nvol_success(ibox), nvolumes(ibox)
       END IF
    END DO
    
    WRITE(chkptunit,'(A)') '********** # of MC steps *********'
    WRITE(chkptunit,'(I12)') this_mc_step
    WRITE(chkptunit,'(A)') '******** Box info ***********'
    
    DO ibox = 1, nbr_boxes
       WRITE(chkptunit,'(I12)') tot_trials(ibox)
       WRITE(chkptunit,'(F19.8)') box_list(ibox)%volume
       WRITE(chkptunit,'(A)') TRIM(box_list(ibox)%box_shape)
       DO ii = 1, 3
          WRITE(chkptunit,'(3(F10.4,1X))') (box_list(ibox)%length(ii,jj), jj=1,3)
       END DO
       
       !--- inverse length
       DO ii = 1, 3
          WRITE(chkptunit,'(3(E12.5,1X))') (box_list(ibox)%length_inv(ii,jj), jj=1,3)
       END DO

       IF (int_sim_type == sim_npt .OR. int_sim_type == sim_gemc .OR. &
            int_sim_type == sim_gemc_npt)  THEN

             WRITE(chkptunit,'(F10.4)') box_list(ibox)%dv_max
          
       END IF
       
    END DO
    WRITE(chkptunit,'(A)') '**** SEEDS *******'
    WRITE(chkptunit,'(5(I21,1X))') s1,s2,s3,s4,s5
    
    WRITE(chkptunit,'(A)') '******* Info for total number of molecules'
    ! write number of molecules of each of the species
    DO is = 1, nspecies
       total_molecules_is = 0
       DO ibox = 1, nbr_boxes
          CALL Get_Nmolecules_Species(ibox,is,nmolecules_is)
          total_molecules_is = total_molecules_is + nmolecules_is
       END DO
       WRITE(chkptunit,'(I3,1X,I10)') is,total_molecules_is
    END DO
    
    
    WRITE(chkptunit,'(A)') '******** Writing coordinates for all the boxes'
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          
          this_im = locate(im,is)
          
          IF(molecule_list(this_im,is)%live) THEN
             this_box = molecule_list(this_im,is)%which_box

             DO ia = 1, natoms(is)
                WRITE(chkptunit,'(A,T10,3(F15.9,1X),T70,I3)') nonbond_list(ia,is)%element, &
                !WRITE(chkptunit,*) nonbond_list(ia,is)%element, &
                     atom_list(ia,this_im,is)%rxp, &
                     atom_list(ia,this_im,is)%ryp, &
                     atom_list(ia,this_im,is)%rzp, this_box
             END DO
          END IF
          
       END DO
    END DO

    CLOSE(unit=chkptunit)
    
  END SUBROUTINE Write_Checkpoint
!**************************************************************************************************

SUBROUTINE Read_NDX

    CHARACTER(charLength) :: line_array(lineArrayLength)
    INTEGER :: is, line_nbr, nbr_entries, ierr, idx, i_ndx, totatoms

    ierr = 0
    nbr_entries = 0
    totatoms = 0
    DO is = 1 , nspecies
        totatoms = totatoms + nmolecules(is) * natoms(is)
    ENDDO

    ALLOCATE( ndx_type( totatoms ) )
    ndx_type(:) = 0

    OPEN(unit=ndx_unit, file=ndx_file)

    idx = 0
    line_nbr = 1
    line_array(:) = ""
    DO 
        CALL Parse_String(ndx_unit,line_nbr,0,nbr_entries,line_array,ierr)
        IF (ierr /= 0) EXIT
        ! skip empty lines
        IF (nbr_entries == 0) CYCLE

        IF (line_array(1) == '[' .AND. line_array(3) == ']') THEN
            IF (line_array(2) /= 'System') THEN
                idx = idx + 1
            END IF
            IF (idx > nspecies ) THEN
                err_msg = ""
                err_msg(1) = "*.ndx file should only have System and nspecies told."
                CALL Clean_Abort(err_msg,'Read_NDX')
            END IF

        ELSE IF ( nbr_entries >= 1 ) THEN
            DO i_ndx = 1, nbr_entries
                ndx_type( String_To_Int( line_array(i_ndx) ) ) = idx
            END DO
        END IF

        line_nbr = line_nbr + 1

    END DO
    CLOSE(unit=ndx_unit)
    IF (idx < nspecies ) THEN
        err_msg = ""
        err_msg(1) = "*.ndx file should have all nspecies told."
        CALL Clean_Abort(err_msg,'Read_NDX')
    END IF

    RETURN

END SUBROUTINE Read_NDX

SUBROUTINE Read_XTC(this_mc_step)

    use, intrinsic :: iso_c_binding, only: C_PTR, c_f_pointer
    use xtc_interface

    INTEGER, INTENT(IN) :: this_mc_step

    INTEGER :: i, ia, im, is, this_im, this_box, ierr, temp_n_equilsteps, step

    REAL(DP) :: xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new

    LOGICAL :: ex

    CHARACTER(1024) :: filename

    real, allocatable :: pos(:,:)
    real :: prec, time, box_trans(3,3), box(3,3)
    type(C_PTR) :: xd_c

    IF ( this_mc_step == -1 ) THEN 
       IF ( read_volume ) THEN
          CALL Read_VOL
       ENDIF

       CALL Read_NDX

       temp_n_equilsteps = n_equilsteps
       n_equilsteps = 1
       CALL Read_GRO(1)
       n_equilsteps = temp_n_equilsteps

       filename = TRIM( xtc_config_file )

       ! Open the file for reading. Convert C pointer to Fortran pointer.
       INQUIRE(file=trim(filename),exist=ex)
       IF (.not. ex) THEN 
          err_msg = ""
          err_msg(1) = "Could not find the xtc file."
          CALL Clean_Abort(err_msg,'Read_XTC')
       END IF
       xd_c = xdrfile_open(filename,"r")
       call c_f_pointer(xd_c,xtc_config_unit)

       ierr = read_xtc_natoms(filename,xtc_natoms)
       ! check xtc_natoms
       IF ( xtc_natoms /= gro_natoms ) THEN
          err_msg = ""
          err_msg(1) = "Found different number of atoms in the xtc and gro files"
          err_msg(2) = "xtc: "//Int_To_String(xtc_natoms)
          err_msg(3) = "gro: "//Int_To_String(gro_natoms)
          CALL Clean_Abort(err_msg,'Read_XTC')
       END IF

    END IF

    IF ( read_volume ) THEN
       IF (MOD(this_mc_step - 1, ivolfreq) == 0) THEN
          CALL Read_VOL
       ENDIF
    ENDIF
    
    ! Read configuration

    allocate(pos(3,xtc_natoms))

    ierr = read_xtc_c(xtc_config_unit,xtc_natoms,step,time,box_trans,pos,prec)

    IF ( 1 == this_mc_step) THEN
        ! C is row-major, whereas Fortran is column major. Hence the following.
        box = transpose(box_trans)
        DO i = 1, 3
           IF ( (1.0 / prec) < ( (box(i,i) * 10.0) - box_list(1)%length(i,i) ) ) THEN
             err_msg = ""
             err_msg(1) = "box dimension in inputfile and xtc do not agree, check units maybe."
             CALL Clean_Abort(err_msg,'Read_XTC')
           END IF
        END DO

    ELSEIF (this_mc_step < n_equilsteps) THEN
        RETURN

    ELSEIF (read_volume .AND. MOD(this_mc_step-1,ivolfreq) /= 0) THEN
        deallocate(pos)
        RETURN

    ELSEIF (ierr /= 0) THEN
        WRITE(logunit,*) 'There are only ', this_mc_step, 'steps in xtc'
        err_msg = ""
        err_msg(1) = "Not as many steps in the xtc file."
        CALL Clean_Abort(err_msg,'Read_XTC')

    END IF

    DO i = 1, xtc_natoms
        ia = ia_atoms(i)
        im = im_atoms(i)
        is = is_atoms(i)

        this_box = molecule_list(im,is)%which_box

        atom_list(ia,im,is)%rxp = pos(1,i) * 10.0_DP - box_list(this_box)%hlength(1,1)
        atom_list(ia,im,is)%ryp = pos(2,i) * 10.0_DP - box_list(this_box)%hlength(2,2)
        atom_list(ia,im,is)%rzp = pos(3,i) * 10.0_DP - box_list(this_box)%hlength(3,3)
    END DO

    deallocate(pos)

    CALL Get_Internal_Coords
    
    ! Calculate COM and distance of the atom farthest to the COM.
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          ! Now let us ensure that the molecular COM is inside the central simulation box
          CALL Get_COM(this_im,is)

          xcom_old = molecule_list(this_im,is)%xcom
          ycom_old = molecule_list(this_im,is)%ycom
          zcom_old = molecule_list(this_im,is)%zcom
          
          ! Apply PBC

          this_box = molecule_list(this_im,is)%which_box

          IF (l_cubic(this_box)) THEN
             CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          ELSE
             CALL Minimum_Image_Separation(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          END IF
          
          ! COM in the central simulation box
          molecule_list(this_im,is)%xcom = xcom_new
          molecule_list(this_im,is)%ycom = ycom_new
          molecule_list(this_im,is)%zcom = zcom_new
          
          ! displace atomic coordinates
          atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
               xcom_new - xcom_old
          atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
               ycom_new - ycom_old
          atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
               zcom_new - zcom_old
          
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO
    
    IF(int_vdw_sum_style(1) == vdw_cut_tail) CALL Compute_Beads(1)

  END SUBROUTINE Read_XTC

SUBROUTINE Read_GRO(this_mc_step)

   INTEGER, INTENT(IN) :: this_mc_step

    INTEGER :: is, im, this_im, ia, this_box, sp_nmoltotal(nspecies)
    INTEGER :: check_nmol

    REAL(DP) :: xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new

    LOGICAL :: lopen

    CHARACTER(240) :: line_string, line_array(80)
    INTEGER :: line_nbr, nbr_entries, ierr, n_lines, i_line, ps
    
    ! Let us read all the counters and count the number of molecules of
    ! each of the species in all the boxes
    nmols(:,:) = 0
    sp_nmoltotal = 0
    molecule_list(:,:)%live = .FALSE.
    molecule_list(:,:)%molecule_type = int_none
    molecule_list(:,:)%cfc_lambda = int_none
    atom_list(:,:,:)%exist = .FALSE.

    IF ( this_mc_step == -1 ) CALL Read_NDX

    line_nbr = 0
    ! Read configuration

    INQUIRE(file=gro_config_file,opened=lopen)
    IF (.not. lopen) OPEN(unit=gro_config_unit, file=gro_config_file)

    READ(gro_config_unit, *) ! read header
    CALL Parse_String(gro_config_unit,line_nbr,1,nbr_entries,line_array,ierr)

    line_nbr = line_nbr + 1
    
    n_lines = String_To_Int(line_array(1))
    IF (n_lines < 0) THEN
       RETURN
    END IF

    im = 1
    ia = 1
    ps = ndx_type(1)
    DO i_line = 1, n_lines 

       IF (this_mc_step < n_equilsteps) THEN
       !IF (1 < this_mc_step .and. this_mc_step < n_equilsteps) THEN
          READ(gro_config_unit, *) 
          CYCLE
       END IF

       CALL Read_String(gro_config_unit,line_string,ierr)
       line_array(1) = TRIM(line_string(1:10))
       line_array(2) = TRIM(line_string(11:15))
       line_array(3) = TRIM(line_string(16:20))
       line_array(4) = TRIM(line_string(21:28))
       line_array(5) = TRIM(line_string(29:36))
       line_array(6) = TRIM(line_string(37:44))

       IF (nvacf_freq /= 0) THEN
          line_array(7) = TRIM(line_string(45:52))
          line_array(8) = TRIM(line_string(53:60))
          line_array(9) = TRIM(line_string(61:68))
       END IF
         
       is = ndx_type( i_line )

       IF ( ia == natoms(is)+1 ) THEN
          im = im + 1
          ia = 1
       END IF

       IF ( is /= ps ) THEN
          im = 1
          ia = 1
          ps = is
       END IF

       IF ( im > nmolecules(is) ) THEN
          err_msg = ""
          err_msg(1) = "Found more than "// TRIM(Int_To_String(nmolecules(is)))//" molecules "
          err_msg(2) = "for species "// TRIM(Int_To_String(is))//" in file:"
          err_msg(3) = TRIM( gro_config_file )
          err_msg(4) = " Check the *.ndx and gro files."
          CALL Clean_Abort(err_msg,'Read_GRO')
       END IF

       IF (.not. molecule_list(im,is)%live) THEN
           ! provide a linked number to this molecule
           locate(im,is) = im 
           this_im = locate(im,is)
           sp_nmoltotal(is) = sp_nmoltotal(is) + 1
           molecule_list(this_im,is)%live = .TRUE.

           ! By default make all the molecules as integer molecules
           molecule_list(this_im,is)%molecule_type = int_normal
           molecule_list(this_im,is)%cfc_lambda = 1.0_DP

           ! assign the box to this molecule
           molecule_list(this_im,is)%which_box = 1
           nmols(is,1) = nmols(is,1) + 1
             
       END IF

       this_im = locate(im,is)

       atom_list(ia,this_im,is)%rxp = String_To_Double(line_array(4)) * 10.0_DP
       atom_list(ia,this_im,is)%ryp = String_To_Double(line_array(5)) * 10.0_DP
       atom_list(ia,this_im,is)%rzp = String_To_Double(line_array(6)) * 10.0_DP
       
       IF (nvacf_freq /= 0) THEN
          atom_list(ia,this_im,is)%vxp = String_To_Double(line_array(7)) * 10.0_DP
          atom_list(ia,this_im,is)%vyp = String_To_Double(line_array(8)) * 10.0_DP
          atom_list(ia,this_im,is)%vzp = String_To_Double(line_array(9)) * 10.0_DP

       END IF

       atom_list(ia,this_im,is)%exist = .TRUE.
       ia_atoms(i_line) = ia
       im_atoms(i_line) = this_im
       is_atoms(i_line) = is

       ia = ia + 1

       line_nbr = line_nbr + 1

    END DO
    gro_natoms = n_lines 

    CALL Parse_String(gro_config_unit,line_nbr,3,nbr_entries,line_array,ierr)
    line_nbr = line_nbr + 1

    ! Check the box size
    IF ( ( ( (box_list(1)%length(1,1) - String_To_Double(line_array(1))*10.0) / &
             box_list(1)%length(1,1)) > 0.001 ) .OR. &
         ( ( (box_list(1)%length(2,2) - String_To_Double(line_array(2))*10.0) / &
             box_list(1)%length(2,2)) > 0.001 ) .OR. &
         ( ( (box_list(1)%length(3,3) - String_To_Double(line_array(3))*10.0) / &
             box_list(1)%length(3,3)) > 0.001 ) ) THEN
          err_msg = ""
          err_msg(1) = "Box size in input and gromacs config do not agree."
          CALL Clean_Abort(err_msg,'Read_GRO')
    ENDIF

    IF (0 .eq. this_mc_step .or. this_mc_step .gt. n_equilsteps) THEN
       check_nmol = 0
       DO is = 1, nspecies
          check_nmol = check_nmol + (nmols(is,1)*natoms(is))
       END DO

       IF (check_nmol .LT. n_lines) THEN
          err_msg = ""
          err_msg(1) = "More molecules in GRO, than possible from nmolecules in the input file."
          CALL Clean_Abort(err_msg,'Read_GRO')
       ENDIF
    ENDIF

    DO is = 1, nspecies
       IF(sp_nmoltotal(is) .LT. nmolecules(is)) THEN
          DO im = sp_nmoltotal(is)+1,nmolecules(is)
             locate(im,is) = im
             molecule_list(im,is)%live = .FALSE.
             molecule_list(im,is)%cfc_lambda = 1.0_DP
             molecule_list(im,is)%molecule_type = int_normal
             molecule_list(im,is)%which_box = 0
          END DO
       END IF
    END DO

    CALL Get_Internal_Coords
    
    ! Calculate COM and distance of the atom farthest to the COM.
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          ! Now let us ensure that the molecular COM is inside the central simulation box
          !
          CALL Get_COM(this_im,is)

          xcom_old = molecule_list(this_im,is)%xcom
          ycom_old = molecule_list(this_im,is)%ycom
          zcom_old = molecule_list(this_im,is)%zcom
          
          ! Apply PBC

          this_box = molecule_list(this_im,is)%which_box

          IF (l_cubic(this_box)) THEN
             
             CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          ELSE
             
             CALL Minimum_Image_Separation(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          END IF
          
          ! COM in the central simulation box
          
          molecule_list(this_im,is)%xcom = xcom_new
          molecule_list(this_im,is)%ycom = ycom_new
          molecule_list(this_im,is)%zcom = zcom_new
          
          ! displace atomic coordinates
          
          atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
               xcom_new - xcom_old
          atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
               ycom_new - ycom_old
          atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
               zcom_new - zcom_old
          
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO
    
    IF(int_vdw_sum_style(1) == vdw_cut_tail) CALL Compute_Beads(1)

  END SUBROUTINE Read_GRO

SUBROUTINE Read_VOL

    INTEGER :: nbr_entries, ierr
    CHARACTER(240) :: line_array(80)
    REAL(DP) :: box_volume, box_length

    CALL Parse_String(volume_info_unit,line_nbr_vol,2,nbr_entries,line_array,ierr)
    line_nbr_vol = line_nbr_vol + 1

    box_volume = String_To_Double(line_array(2))
    box_length = box_volume ** (1./3.)

    box_list(1)%volume = box_volume

    ! specific for cubic boxes
    box_list(1)%length(1,1) = box_length
    box_list(1)%length(2,2) = box_length
    box_list(1)%length(3,3) = box_length

    box_list(1)%hlength(1,1) = 0.5_DP * box_list(1)%length(1,1)
    box_list(1)%hlength(2,2) = 0.5_DP * box_list(1)%length(2,2)
    box_list(1)%hlength(3,3) = 0.5_DP * box_list(1)%length(3,3)

    !CALL Compute_Cell_Dimensions(1)

    END SUBROUTINE Read_VOL

SUBROUTINE Read_XYZ(this_mc_step)

   INTEGER, INTENT(IN) :: this_mc_step

    INTEGER :: ibox, is, im, this_im, ia, this_box, sp_nmoltotal(nspecies)
    INTEGER :: check_nmol

    REAL(DP) :: xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new

    LOGICAL :: lopen

    CHARACTER(240) :: line_array(80)
    INTEGER :: line_nbr, nbr_entries, ierr, n_lines, i_line
    
    ! Let us read all the counters and count the number of molecules of
    ! each of the species in all the boxes
    nmols(:,:) = 0
    sp_nmoltotal = 0
    molecule_list(:,:)%live = .FALSE.
    molecule_list(:,:)%molecule_type = int_none
    molecule_list(:,:)%cfc_lambda = int_none
    atom_list(:,:,:)%exist = .FALSE.
    line_array = ''
    n_lines = 0
    
    line_nbr = 1
    DO ibox = 1, nbr_boxes

       INQUIRE(file=xyz_config_file(ibox),opened=lopen)
       IF (.not. lopen) OPEN(unit=xyz_config_unit(ibox), file=xyz_config_file(ibox))
       CALL Parse_String(xyz_config_unit(ibox),line_nbr,1,nbr_entries,line_array,ierr)
       line_nbr = line_nbr + 1
       
       n_lines = String_To_Int(line_array(1))
       IF (n_lines < 0) THEN
          CLOSE(unit=xyz_config_unit(ibox))
          IF (ibox == nbr_boxes) THEN
             RETURN
          ELSE
             CYCLE
          END IF
       ELSE IF (nbr_entries > 3) THEN
          err_msg = ""
          err_msg(1) = "Too many entries for number of atoms line, probably end of file"
          CALL Clean_Abort(err_msg,'Read_XYZ')
       END IF

       CALL Parse_String(xyz_config_unit(ibox),line_nbr,0,nbr_entries,line_array,ierr)
       line_nbr = line_nbr + 1

       ia = 1
       DO i_line = 1, n_lines 

          IF (1 < this_mc_step .and. this_mc_step < n_equilsteps) THEN
             READ(xyz_config_unit(ibox), *) 
             CYCLE
          END IF
          line_nbr = line_nbr + 1

          CALL Parse_String(xyz_config_unit(ibox),line_nbr,6,nbr_entries,line_array,ierr)

          is = String_To_Int(line_array(5))
          im = String_To_Int(line_array(6))
        
          !DO i = 1, natoms(is)
          !   IF (line_array(1) == nonbond_list(i,is)%element) THEN
          !      ia = i
          !      EXIT
          !   END IF
          !END DO
          IF ( im > nmolecules(is) ) THEN
             err_msg = ""
             err_msg(1) = 'Number of molecules in xyz file exceeds limit of ' // &
                  INT_to_String(nmolecules(is)) 
             err_msg(2) = 'Increase molecule number limit in input file '
             CALL Clean_Abort(err_msg,'Read_XYZ')
          END IF

          IF (.not. molecule_list(im,is)%live) THEN
              ! provide a linked number to this molecule
              locate(im,is) = im 
              this_im = locate(im,is)
              sp_nmoltotal(is) = sp_nmoltotal(is) + 1
              molecule_list(this_im,is)%live = .TRUE.

              ! By default make all the molecules as integer molecules
              molecule_list(this_im,is)%molecule_type = int_normal
              molecule_list(this_im,is)%cfc_lambda = 1.0_DP

              ! assign the box to this molecule
              molecule_list(this_im,is)%which_box = ibox
              nmols(is,ibox) = nmols(is,ibox) + 1
              ia = 1
                
          END IF

          !IF (line_array(1) /= nonbond_list(ia,is)%element) THEN
          IF (line_array(1) /= nonbond_list(ia,is)%atom_name) THEN
             err_msg = ""
             err_msg(1) = "An atom name in the xyz file ("//TRIM(line_array(1))//") does not match the name in the mcf file."
             err_msg(2) = "Consider the order..."

             CALL Clean_Abort(err_msg,'Read_XYZ')
          END IF

          this_im = locate(im,is)

          ia_atoms(i_line) = ia
          im_atoms(i_line) = this_im
          is_atoms(i_line) = is
          
          atom_list(ia,this_im,is)%rxp = String_To_Double(line_array(2))
          atom_list(ia,this_im,is)%ryp = String_To_Double(line_array(3))
          atom_list(ia,this_im,is)%rzp = String_To_Double(line_array(4))
          
          atom_list(ia,this_im,is)%exist = .TRUE.

          line_nbr = line_nbr + 1
          ia = ia + 1

       END DO

       IF (0 .eq. this_mc_step .or. this_mc_step .gt. n_equilsteps) THEN
          check_nmol = 0
          DO is = 1, nspecies
             check_nmol = check_nmol + (nmols(is,ibox)*natoms(is))
          END DO

          IF (check_nmol .LT. n_lines) THEN
             err_msg = ""
             err_msg(1) = "More molecules in XYZ, than possible from nmolecules in the input file."
             err_msg(2) = "Or too many mcsteps in the input file."
             CALL Clean_Abort(err_msg,'Read_XYZ')
          ENDIF
       ENDIF

    END DO

    DO is = 1, nspecies
       IF(sp_nmoltotal(is) .LT. nmolecules(is)) THEN
          DO im = sp_nmoltotal(is)+1,nmolecules(is)
             locate(im,is) = im
             molecule_list(im,is)%live = .FALSE.
             molecule_list(im,is)%cfc_lambda = 1.0_DP
             molecule_list(im,is)%molecule_type = int_normal
             molecule_list(im,is)%which_box = 0
          END DO
       END IF
    END DO

    CALL Get_Internal_Coords
    
    ! Calculate COM and distance of the atom farthest to the COM.
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          ! Now let us ensure that the molecular COM is inside the central simulation box
          !
          CALL Get_COM(this_im,is)
          
          xcom_old = molecule_list(this_im,is)%xcom
          ycom_old = molecule_list(this_im,is)%ycom
          zcom_old = molecule_list(this_im,is)%zcom
          
          ! Apply PBC

          this_box = molecule_list(this_im,is)%which_box

          IF (.not. lattice_sim) THEN

          IF (l_cubic(this_box)) THEN
             
             CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          ELSE
             
             CALL Minimum_Image_Separation(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          END IF

          
          ! COM in the central simulation box
          
          molecule_list(this_im,is)%xcom = xcom_new
          molecule_list(this_im,is)%ycom = ycom_new
          molecule_list(this_im,is)%zcom = zcom_new
          
          ! displace atomic coordinates
          
          atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
               xcom_new - xcom_old
          atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
               ycom_new - ycom_old
          atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
               zcom_new - zcom_old

          END IF
          
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO
    
    DO ibox = 1, nbr_boxes
       IF(int_vdw_sum_style(ibox) == vdw_cut_tail) CALL Compute_Beads(ibox)
    END DO

  END SUBROUTINE Read_XYZ

SUBROUTINE Read_DCD(this_mc_step)
    INTEGER, INTENT(IN) :: this_mc_step

    INTEGER :: i, ia, im, is, this_im, this_box, ierr, temp_n_equilsteps

    REAL(DP) :: xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new

    LOGICAL :: ex

    CHARACTER(1024) :: filename

    real, allocatable :: pos(:,:)
    real :: box(6)

    CHARACTER(4) :: HDR 
    INTEGER, DIMENSION(20) :: ICNTRL
    REAL(4) :: delta

    this_box = 1
    box = 0.0

    IF ( this_mc_step == -1 ) THEN 
       
       IF ( read_volume ) THEN
          CALL Read_VOL
       ENDIF

       temp_n_equilsteps = n_equilsteps
       n_equilsteps = 1
       CALL Read_XYZ(1)
       xyz_natoms = 0
       DO is = 1, nspecies
          xyz_natoms = xyz_natoms + (nmols(is,this_box)*natoms(is))
       END DO

       n_equilsteps = temp_n_equilsteps

       filename = TRIM( dcd_config_file )

       ! Open the file for reading. Convert C pointer to Fortran pointer.
       INQUIRE(file=trim(filename),exist=ex)
       IF (.not. ex) THEN 
          err_msg = ""
          err_msg(1) = "Could not find the dcd file."
          CALL Clean_Abort(err_msg,'Read_DCD')
       END IF
       OPEN(UNIT=dcd_config_unit, FILE=dcd_config_file, FORM = 'unformatted',STATUS= 'old')
   
       ! Read the header information
       READ(dcd_config_unit) HDR, (ICNTRL(i),i=1,9),delta,(ICNTRL(i),i=11,20)          
       READ(dcd_config_unit) 
       READ(dcd_config_unit) dcd_natoms

       IF ( dcd_natoms /= xyz_natoms ) THEN
          err_msg = ""
          err_msg(1) = "Found different number of atoms in the dcd and gro files"
          err_msg(2) = "dcd: "//Int_To_String(dcd_natoms)
          err_msg(3) = "xyz: "//Int_To_String(xyz_natoms)
          CALL Clean_Abort(err_msg,'Read_DCD')
       END IF
       IF(ICNTRL(11) .EQ. 1) THEN
          read_dcd_box = .true.
       END IF

    END IF
    
    ! Read the periodic bounday informatin if present (not used!)
    IF(read_dcd_box) THEN
      READ(dcd_config_unit,IOSTAT=ierr) (box(i),i=1,6)
    ENDIF

    ! Read the atomic coordinates from the DCD trajectory file
    allocate(pos(3,dcd_natoms))
    READ(dcd_config_unit,IOSTAT=ierr) (pos(1, im),im=1,dcd_natoms)
    READ(dcd_config_unit,IOSTAT=ierr) (pos(2, im),im=1,dcd_natoms)
    READ(dcd_config_unit,IOSTAT=ierr) (pos(3, im),im=1,dcd_natoms)

    IF ( 1 == this_mc_step) THEN
        ! C is row-major, whereas Fortran is column major. Hence the following.
        DO i = 1, 3
           IF ( (1.0 / 1000) < ( box(i) - box_list(1)%length(i,i) ) ) THEN
             deallocate(pos)
             err_msg = ""
             err_msg(1) = "box dimension in inputfile and dcd do not agree, check units maybe."
             CALL Clean_Abort(err_msg,'Read_DCD')
           END IF
        END DO

    ELSEIF (this_mc_step < n_equilsteps) THEN
        deallocate(pos)
        RETURN

    ELSEIF (read_volume .AND. MOD(this_mc_step-1,ivolfreq) /= 0) THEN
        deallocate(pos)
        RETURN

    ELSEIF (ierr /= 0) THEN
        deallocate(pos)
        WRITE(logunit,*) 'There are only ', this_mc_step, 'steps in dcd file'
        err_msg = ""
        err_msg(1) = "Not as many steps in the dcd file."
        CALL Clean_Abort(err_msg,'Read_DCD')
    END IF

    !IF ( read_volume ) THEN
    IF ( read_volume ) THEN
       IF (MOD(this_mc_step - 1, ivolfreq) == 0) THEN
          CALL Read_VOL
       ENDIF
    ENDIF
    

    DO i = 1, dcd_natoms
        ia = ia_atoms(i)
        im = im_atoms(i)
        is = is_atoms(i)

        atom_list(ia,im,is)%rxp = DBLE( pos(1,i) )
        atom_list(ia,im,is)%ryp = DBLE( pos(2,i) )
        atom_list(ia,im,is)%rzp = DBLE( pos(3,i) )
    END DO

    deallocate(pos)

    CALL Get_Internal_Coords
    
    ! Calculate COM and distance of the atom farthest to the COM.
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          ! Now let us ensure that the molecular COM is inside the central simulation box
          CALL Get_COM(this_im,is)

          xcom_old = molecule_list(this_im,is)%xcom
          ycom_old = molecule_list(this_im,is)%ycom
          zcom_old = molecule_list(this_im,is)%zcom
          
          ! Apply PBC

          this_box = molecule_list(this_im,is)%which_box

          IF (l_cubic(this_box)) THEN
             CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          ELSE
             CALL Minimum_Image_Separation(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

          END IF
          
          ! COM in the central simulation box
          molecule_list(this_im,is)%xcom = xcom_new
          molecule_list(this_im,is)%ycom = ycom_new
          molecule_list(this_im,is)%zcom = zcom_new
          
          ! displace atomic coordinates
          atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
               xcom_new - xcom_old
          atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
               ycom_new - ycom_old
          atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
               zcom_new - zcom_old
          
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO
    
    IF(int_vdw_sum_style(1) == vdw_cut_tail) CALL Compute_Beads(1)

  END SUBROUTINE Read_DCD

SUBROUTINE Read_Checkpoint

    INTEGER :: this_mc_step

    INTEGER :: ibox, is, ii, jj, im, this_im, ia, this_box, mols_this, sp_nmoltotal(nspecies)
    INTEGER :: this_species
    INTEGER :: this_unit
    INTEGER :: line_nbr, nbr_entries, ierr

    INTEGER, DIMENSION(:), ALLOCATABLE :: total_molecules, n_int

    REAL(DP) :: this_lambda, xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new

    LOGICAL :: f_checkpoint, f_read_old
    LOGICAL :: lopen

    CHARACTER(240) :: line_array(80)

    ALLOCATE(total_molecules(nspecies))
    ALLOCATE(n_int(nspecies))
    IF(.NOT. ALLOCATED(ntrials)) ALLOCATE(ntrials(nspecies,nbr_boxes))
    IF(.NOT. ALLOCATED(tot_trials)) ALLOCATE(tot_trials(nbr_boxes))
    
    INQUIRE(file=restart_file,opened=lopen)
    IF (lopen) INQUIRE(file=restart_file, number = this_unit)
    IF (lopen) CLOSE(unit=this_unit)

    OPEN(unit=restartunit,file=restart_file)
    ! Let us read all the counters and count the number of molecules of
    ! each of the species in all the boxes
    nmols(:,:) = 0
    n_int(:) = 0
    
    line_nbr = 1
    READ(restartunit,*)

    f_checkpoint = .FALSE.
    f_read_old = .FALSE.
    IF (start_type == 'checkpoint') f_checkpoint = .TRUE.
    IF (start_type == 'read_old') f_read_old = .TRUE.

    DO ibox = 1, nbr_boxes

       DO is = 1, nspecies
          
          ! read information only if start_type == checkpoint
          
          IF (f_checkpoint) THEN
             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,5,nbr_entries,line_array,ierr)
             this_species = String_To_Int( line_array(1) )
             ntrials(is,ibox)%displacement = String_To_Int( line_array(2) )
             ntrials(is,ibox)%rotation = String_To_Int( line_array(3) )
             ntrials(is,ibox)%dihedral = String_To_Int( line_array(4) )
             ntrials(is,ibox)%angle = String_To_Int( line_array(5) )

             !READ(restartunit,*) this_species, ntrials(is,ibox)%displacement, &
             !READ(restartunit,'(5(I10,1x))') this_species, ntrials(is,ibox)%displacement, &
             !     ntrials(is,ibox)%rotation, ntrials(is,ibox)%dihedral, &
             !     ntrials(is,ibox)%angle

             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,5,nbr_entries,line_array,ierr)
             this_species = String_To_Int( line_array(1) )
             nsuccess(is,ibox)%displacement = String_To_Int( line_array(2) )
             nsuccess(is,ibox)%rotation = String_To_Int( line_array(3) )
             nsuccess(is,ibox)%dihedral = String_To_Int( line_array(4) )
             nsuccess(is,ibox)%angle = String_To_Int( line_array(5) )
             !READ(restartunit,'(5(I10,1x))') this_species, nsuccess(is,ibox)%displacement, &
             !     nsuccess(is,ibox)%rotation, nsuccess(is,ibox)%dihedral, &
             !     nsuccess(is,ibox)%angle
             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,3,nbr_entries,line_array,ierr)
             max_disp(is,ibox) = String_To_Double( line_array(1) )
             max_rot(is,ibox) = String_To_Double( line_array(2) )
             species_list(is)%max_torsion = String_To_Double( line_array(3) )
             !READ(restartunit,'(3(E24.15))') max_disp(is,ibox), max_rot(is,ibox), &
             !     species_list(is)%max_torsion

          ELSE IF (f_read_old) THEN

             READ(restartunit,*)
             READ(restartunit,*)
             READ(restartunit,*)
             line_nbr = line_nbr + 3

          END IF

       END DO
       
       IF (int_sim_type == sim_npt .OR. int_sim_type == sim_gemc .OR. &
            int_sim_type == sim_gemc_npt) THEN

          line_nbr = line_nbr + 1
          IF (f_checkpoint) THEN
             CALL Parse_String(restartunit,line_nbr,2,nbr_entries,line_array,ierr)
             nvol_success(ibox) = String_To_Int( line_array(1) )
             nvolumes(ibox) = String_To_Int( line_array(2) )
             !READ(restartunit,'(I10,1x,I10)') nvol_success(ibox), nvolumes(ibox)
          ELSE IF (f_read_old) THEN
             READ(restartunit,*)
          END IF

       END IF
    END DO
    
    line_nbr = line_nbr + 1
    READ(restartunit,*)
    line_nbr = line_nbr + 1
    CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
    this_mc_step = String_To_Int( line_array(1) )
    !READ(restartunit,'(I12)') this_mc_step
    line_nbr = line_nbr + 1
    READ(restartunit,*) 
    
    DO ibox = 1, nbr_boxes

       IF (f_checkpoint) THEN
          line_nbr = line_nbr + 1
          CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
          tot_trials(ibox) = String_To_Int( line_array(1) )
          
          line_nbr = line_nbr + 1
          CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
          box_list(ibox)%volume = String_To_Double( line_array(1) )
          
          line_nbr = line_nbr + 1
          CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
          box_list(ibox)%box_shape = TRIM( line_array(1) )
          
          !READ(restartunit,'(I12)') tot_trials(ibox)
          !READ(restartunit,'(F19.8)') box_list(ibox)%volume
          !READ(restartunit,'(A)') box_list(ibox)%box_shape
          
          DO ii = 1, 3
             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,3,nbr_entries,line_array,ierr)
             DO jj = 1, 3
                box_list(ibox)%length(ii,jj) = String_To_Double( line_array(jj) )
             END DO
             !READ(restartunit,'(3(F10.4,1X))') (box_list(ibox)%length(ii,jj), jj=1,3)
          END DO
          
          !--- inverse length
          DO ii = 1, 3
             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,3,nbr_entries,line_array,ierr)
             DO jj = 1, 3
                box_list(ibox)%length_inv(ii,jj) = String_To_Double( line_array(jj) )
             END DO
             !READ(restartunit,'(3(E12.5,1X))') (box_list(ibox)%length_inv(ii,jj), jj=1,3)          
          END DO

          CALL Compute_Cell_Dimensions(ibox)
                    
       ELSE IF (f_read_old) THEN

          READ(restartunit,*)
          READ(restartunit,*)
          READ(restartunit,*)

          ! skip box length and box length inverse information

          DO ii = 1, 3
             READ(restartunit,*)
          END DO

          DO ii = 1, 3
             READ(restartunit,*)
          END DO

          line_nbr = line_nbr + 9
       END IF

       
       IF (int_sim_type == sim_npt .OR. int_sim_type == sim_gemc .OR. &
            int_sim_type == sim_gemc_npt) THEN
          
          line_nbr = line_nbr + 1
          IF (f_checkpoint) THEN
             CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
             box_list(ibox)%dv_max = String_To_Double( line_array(1) )
             !READ(restartunit,'(F10.4)') box_list(ibox)%dv_max          
          ELSE
             READ(restartunit,*)
          END IF

       END IF
       
    END DO
    
    line_nbr = line_nbr + 1
    READ(restartunit,*)

    line_nbr = line_nbr + 1
    IF (f_checkpoint) THEN
        CALL Parse_String(restartunit,line_nbr,3,nbr_entries,line_array,ierr)
        s1 = String_To_Int( line_array(1) )
        s2 = String_To_Int( line_array(2) )
        s3 = String_To_Int( line_array(3) )
        IF ( nbr_entries == 3) THEN
           line_nbr = line_nbr + 1
           CALL Parse_String(restartunit,line_nbr,2,nbr_entries,line_array,ierr)
           s4 = String_To_Int( line_array(1) )
           s5 = String_To_Int( line_array(2) )
        ELSE
           s4 = String_To_Int( line_array(4) )
           s5 = String_To_Int( line_array(5) )
        END IF
!       READ(restartunit,*) iseed1, iseed3
        !READ(restartunit,'(5(I21,1X))') s1,s2,s3,s4,s5
    ELSE
       READ(restartunit,*)
    END IF

    ! read total number of molecules of each of the species

    line_nbr = line_nbr + 1
    READ(restartunit,*)
    DO is = 1, nspecies
       line_nbr = line_nbr + 1
       CALL Parse_String(restartunit,line_nbr,2,nbr_entries,line_array,ierr)
       this_species = String_To_Int( line_array(1) )
       sp_nmoltotal(is) = String_To_Int( line_array(2) )
       !READ(restartunit,'(I3,I10)') this_species, sp_nmoltotal(is)

       IF (sp_nmoltotal(is) > nmolecules(is)) THEN
          err_msg = ""
          err_msg(1) = "More molecules in the checkpoint file than allowed in the input."
          CALL Clean_Abort(err_msg,'Read_Checkpoint')
       END IF
    END DO
    
    line_nbr = line_nbr + 1
    READ(restartunit,*)
    
    DO is = 1, nspecies

       mols_this = 0

       DO im = 1, sp_nmoltotal(is)
          
          ! provide a linked number to this molecule
          locate(im,is) = im + mols_this
          
          this_im = locate(im,is)
          
          molecule_list(this_im,is)%live = .TRUE.

          this_lambda = 1.0_DP
          
          ! By default make all the molecules as integer molecules
          
          molecule_list(this_im,is)%molecule_type = int_normal

          molecule_list(this_im,is)%cfc_lambda = this_lambda

          DO ia = 1, natoms(is)

             line_nbr = line_nbr + 1
             CALL Parse_String(restartunit,line_nbr,4,nbr_entries,line_array,ierr)
             nonbond_list(ia,is)%element = TRIM( line_array(1) )
             atom_list(ia,this_im,is)%rxp = String_To_Double( line_array(2) )
             atom_list(ia,this_im,is)%ryp = String_To_Double( line_array(3) )
             atom_list(ia,this_im,is)%rzp = String_To_Double( line_array(4) )
             IF (nbr_entries == 4) THEN
                line_nbr = line_nbr + 1
                CALL Parse_String(restartunit,line_nbr,1,nbr_entries,line_array,ierr)
                this_box = String_To_Int( line_array(1) )
             ELSE
                this_box = String_To_Int( line_array(5) )
             END IF
             !READ(restartunit,*) this_box
!             READ(restartunit,'(A,T10,3(F15.10,1X),T70,I3)') &
!                  nonbond_list(ia,is)%element, &
!                  atom_list(ia,this_im,is)%rxp, &
!                  atom_list(ia,this_im,is)%ryp, &
!                  atom_list(ia,this_im,is)%rzp, &
!                  this_box
             !READ(restartunit,*) this_box
             ! set the cfc_lambda and exist flags for this atom
             atom_list(ia,this_im,is)%exist = .TRUE.
          END DO

          ! assign the box to this molecule
             
          molecule_list(this_im,is)%which_box = this_box
          nmols(is,this_box) = nmols(is,this_box) + 1
                
       END DO
    END DO

    DO is = 1, nspecies
       IF(sp_nmoltotal(is) .LT. nmolecules(is)) THEN
          DO im = sp_nmoltotal(is)+1,nmolecules(is)
             locate(im,is) = im
             molecule_list(im,is)%live = .FALSE.
             molecule_list(im,is)%cfc_lambda = 1.0_DP
             molecule_list(im,is)%molecule_type = int_normal
             molecule_list(im,is)%which_box = 0
          END DO
       END IF
    END DO

       
    CALL Get_Internal_Coords
    
    ! Calculate COM and distance of the atom farthest to the COM.
    
    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          ! Now let us ensure that the molecular COM is inside the central simulation box
          !
          CALL Get_COM(this_im,is)
          
          xcom_old = molecule_list(this_im,is)%xcom
          ycom_old = molecule_list(this_im,is)%ycom
          zcom_old = molecule_list(this_im,is)%zcom
          
          ! Apply PBC

          this_box = molecule_list(this_im,is)%which_box

          IF (l_cubic(this_box)) THEN
             
             CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

!!$             IF (this_box == 2) THEN
!!$                write(203,*) atom_list(1,this_im,is)%rxp, atom_list(1,this_im,is)%ryp, &
!!$                     atom_list(1,this_im,is)%rzp
!!$             END IF
!!$             write(*,*) 'cubic'
             
          ELSE
             
             CALL Minimum_Image_Separation(this_box,xcom_old,ycom_old,zcom_old, &
                  xcom_new, ycom_new, zcom_new)

!             write(*,*) 'minimum'
             
          END IF
          
          ! COM in the central simulation box
          
          molecule_list(this_im,is)%xcom = xcom_new
          molecule_list(this_im,is)%ycom = ycom_new
          molecule_list(this_im,is)%zcom = zcom_new
          
          ! displace atomic coordinates
          
          atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
               xcom_new - xcom_old
          atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
               ycom_new - ycom_old
          atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
               zcom_new - zcom_old
          
          nmols(is,this_box) = nmols(is,this_box) + 1
          
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO
    
    
    IF ( f_read_old) THEN
       
       DO is = 1, nspecies
          species_list(is)%nmoltotal = SUM(nmols(is,:))
       END DO
       
       WRITE(logunit,*) 'Configurations read successfully'
    END IF


    DO ibox = 1, nbr_boxes
       IF(int_vdw_sum_style(ibox) == vdw_cut_tail) CALL Compute_Beads(ibox)
    END DO

    IF(ALLOCATED(total_molecules)) DEALLOCATE(total_molecules)

  END SUBROUTINE Read_Checkpoint

!*******************************************************************************************************
  
  SUBROUTINE Restart_From_Old
    !***************************************************************************************************
    ! The subroutine reads in a configuration to start a new simulation run. The format of the input
    ! file is identical to the checkpoint file in terms of atomic coordinates.
    !
    !
    !***************************************************************************************************
    
    IMPLICIT NONE
    
    INTEGER :: ibox, is, im, ia, this_im, mols_this
    INTEGER, DIMENSION(:), ALLOCATABLE ::  total_molecules_this
    INTEGER, DIMENSION(:), ALLOCATABLE :: n_int
    
    REAL(DP) :: this_lambda
    REAL(DP) :: xcom_old, ycom_old, zcom_old
    REAL(DP) :: xcom_new, ycom_new, zcom_new
  
    ! Loop over total number of boxes to read in the atomic coordinates

    ALLOCATE(total_molecules_this(nspecies))

    ALLOCATE(n_int(nspecies))

    nmols(:,:) = 0
    n_int(:) = 0
    
    DO ibox = 1, nbr_boxes
       
       OPEN(unit = old_config_unit,file=old_config_file(ibox))
       ! Read the number of molecules for each of the species
       
       READ(old_config_unit,*) (total_molecules_this(is), is = 1, nspecies)
       
       ! Read in the coordinates of the molecules
       
       DO is = 1, nspecies
          
          ! sum the total number of molecules of this species upto ibox - 1. This information
          ! will then be used to provide a locate number for molecules of species 'is', in 'ibox'

          IF (ibox /= 1) THEN
             mols_this = SUM(nmols(is,1:ibox-1))
          ELSE
             mols_this = 0

          END IF

          DO im = 1, total_molecules_this(is)
             ! provide a linked number to the molecule
             locate(im + mols_this,is) = im + mols_this
             this_im = locate(im + mols_this,is)
!             write(*,*) locate(this_im,is)
             molecule_list(this_im,is)%live = .TRUE.
             this_lambda = 1.0_DP
            ! By default all the molecules are normal 
             molecule_list(this_im,is)%molecule_type = int_normal
             
             DO ia = 1, natoms(is)
                
                READ(old_config_unit,*)nonbond_list(ia,is)%element, &
                     atom_list(ia,this_im,is)%rxp, &
                     atom_list(ia,this_im,is)%ryp, &
                     atom_list(ia,this_im,is)%rzp
                ! set the cfc_lambda and exist flags for this atom
                molecule_list(this_im,is)%cfc_lambda = this_lambda
                atom_list(ia,this_im,is)%exist = .TRUE.                
                
             END DO

             ! assign the molecule the box id
             
             molecule_list(this_im,is)%which_box = ibox
        ! Now let us ensure that the molecular COM is inside the central simulation box
          !
             CALL Get_COM(this_im,is)

             xcom_old = molecule_list(this_im,is)%xcom
             ycom_old = molecule_list(this_im,is)%ycom
             zcom_old = molecule_list(this_im,is)%zcom

             ! Apply PBC

             IF (l_cubic(ibox)) THEN

                CALL Apply_PBC_Anint(ibox,xcom_old,ycom_old,zcom_old, &
                     xcom_new, ycom_new, zcom_new)

             ELSE

                CALL Minimum_Image_Separation(ibox,xcom_old,ycom_old,zcom_old, &
                     xcom_new, ycom_new, zcom_new)

             END IF

             ! COM in the central simulation box

             molecule_list(this_im,is)%xcom = xcom_new
             molecule_list(this_im,is)%ycom = ycom_new
             molecule_list(this_im,is)%zcom = zcom_new

             ! COM in the central simulation box

             molecule_list(this_im,is)%xcom = xcom_new
             molecule_list(this_im,is)%ycom = ycom_new
             molecule_list(this_im,is)%zcom = zcom_new

             ! displace atomic coordinates

             atom_list(1:natoms(is),this_im,is)%rxp = atom_list(1:natoms(is),this_im,is)%rxp + &
                  xcom_new - xcom_old
             atom_list(1:natoms(is),this_im,is)%ryp = atom_list(1:natoms(is),this_im,is)%ryp + &
                  ycom_new - ycom_old
             atom_list(1:natoms(is),this_im,is)%rzp = atom_list(1:natoms(is),this_im,is)%rzp + &
                  zcom_new - zcom_old

             nmols(is,ibox) = nmols(is,ibox) + 1
             
          END DO
          
       END DO

       CLOSE(unit = old_config_unit)
       
    END DO

    CALL Get_Internal_Coords

   ! Calculate COM and distance of the atom farthest to the COM.

    DO is = 1, nspecies
       DO im = 1, nmolecules(is)
          this_im = locate(im,is)
          IF( .NOT. molecule_list(this_im,is)%live) CYCLE
          CALL Get_COM(this_im,is)
          CALL Compute_Max_COM_Distance(this_im,is)
       END DO
    END DO

    DO is = 1, nspecies
       species_list(is)%nmoltotal = SUM(nmols(is,:))
    END DO

    WRITE(logunit,*) 'Configurations read successfully'

    DO ibox = 1, nbr_boxes
       IF (int_vdw_sum_style(ibox) == vdw_cut_tail) CALL Compute_Beads(ibox)
    END DO

    DEALLOCATE( total_molecules_this)
    
  END SUBROUTINE Restart_From_Old
!***************************************************************************************

SUBROUTINE Write_Trials_Success
  ! This subroutine writes number of trials and acceptance of these trials at the
  ! end of a simulation

  IMPLICIT NONE

  INTEGER :: ibox, is, ifrag

  WRITE(logunit,*)
  WRITE(logunit,*)

  DO ibox = 1, nbr_boxes

     WRITE(logunit,'(A28,2X,I2)') ' Writing information for box', ibox
     WRITE(logunit,*) ' *********************************************'
     WRITE(logunit,*)

     IF (nvolumes(ibox) /= 0 ) THEN
        WRITE(logunit,'(A20,2x,A10,2x,A10)') 'Move', 'Trials', 'Success'
        WRITE(logunit,11) 'Volume', nvolumes(ibox), nvol_success(ibox)
     END IF

     DO is = 1, nspecies
        
        WRITE(logunit,*) 
        WRITE(logunit,*) ' ******************************************'
        WRITE(logunit,*) ' Writing information for species', is
        WRITE(logunit,*)
        WRITE(logunit,'(A20,2x,A10,2x,A10,2x,A10)') 'Move', 'Trials', 'Success', '% Success'
        
        ! translation

        IF (ntrials(is,ibox)%displacement /= 0 ) THEN
        
           WRITE(logunit,11) 'Translate', ntrials(is,ibox)%displacement, &
                nsuccess(is,ibox)%displacement &
                ,100.0*dble(nsuccess(is,ibox)%displacement)/dble(ntrials(is,ibox)%displacement)
        END IF

        ! rotation

        IF (ntrials(is,ibox)%rotation /= 0 ) THEN
                                   
           WRITE(logunit,11) 'Rotate',  ntrials(is,ibox)%rotation, &
                nsuccess(is,ibox)%rotation, &
                100.0*dble(nsuccess(is,ibox)%rotation)/dble(ntrials(is,ibox)%rotation)

        END IF

        ! Angle

        IF (ntrials(is,ibox)%angle /=0 ) THEN

           WRITE(logunit,11) 'Angle',  ntrials(is,ibox)%angle, &
                nsuccess(is,ibox)%angle, &
                100.0*dble(nsuccess(is,ibox)%angle)/dble(ntrials(is,ibox)%angle)

        END IF


        ! Dihedral

        IF (ntrials(is,ibox)%dihedral /= 0 ) THEN

           WRITE(logunit,11) 'Dihedral', ntrials(is,ibox)%dihedral, &
                nsuccess(is,ibox)%dihedral, &
                100.0*dble(nsuccess(is,ibox)%dihedral)/dble(ntrials(is,ibox)%dihedral)

        END IF

        ! insertion

        IF (ntrials(is,ibox)%insertion /= 0 ) THEN
           
           WRITE(logunit,11) 'Insertion',  ntrials(is,ibox)%insertion, &
                nsuccess(is,ibox)%insertion, &
                100.0*dble(nsuccess(is,ibox)%insertion)/dble(ntrials(is,ibox)%insertion)
        END IF

        ! deletion

        IF (ntrials(is,ibox)%deletion /= 0 ) THEN
           
           WRITE(logunit,11) 'Deletion', ntrials(is,ibox)%deletion, &
                nsuccess(is,ibox)%deletion, &
                100.0*dble(nsuccess(is,ibox)%deletion)/dble(ntrials(is,ibox)%deletion)

        END IF

        ! cluster trans

        IF (ntrials(is,ibox)%cluster_translate /= 0 ) THEN
           
           WRITE(logunit,11) 'Cluster Translation', ntrials(is,ibox)%cluster_translate, &
                nsuccess(is,ibox)%cluster_translate, &
                100.0*dble(nsuccess(is,ibox)%cluster_translate)/dble(ntrials(is,ibox)%cluster_translate)

        END IF

        ! atom displacement

        IF (ntrials(is,ibox)%disp_atom /= 0 ) THEN
           
           WRITE(logunit,11) 'Atom Displacement', ntrials(is,ibox)%disp_atom, &
                nsuccess(is,ibox)%disp_atom, &
                100.0*dble(nsuccess(is,ibox)%disp_atom)/dble(ntrials(is,ibox)%disp_atom)

        END IF
        WRITE(logunit,*) '**************************************'
        WRITE(logunit,*)
     END DO
        
  END DO

11 FORMAT(A20,2x,I10,2x,I10,2x,f10.2)
12 FORMAT(3(I10,2x),F10.2)

  IF( SUM(nfragments) .GT. 0 ) THEN

     WRITE(logunit,*) 'Writing information about fragments'
  
     DO is = 1, nspecies
        
        IF (species_list(is)%fragment) THEN
 
           WRITE(logunit,*)
           WRITE(logunit,*)'*************************************'
           WRITE(logunit,'(A31,2X,I2)') 'Writing information for species', is
           WRITE(logunit,'(A10,2x,A10,2x,A10,2X,A10)') 'Fragment', 'Trials', 'Success', '% Success'

           DO ifrag = 1, nfragments(is)
              
              IF (regrowth_trials(ifrag,is) /= 0 ) THEN
                 WRITE(logunit,12) ifrag,regrowth_trials(ifrag,is), &
                      regrowth_success(ifrag,is), &
                      100.0_DP * dble(regrowth_success(ifrag,is))/dble(regrowth_trials(ifrag,is))
              END IF
           END DO
           WRITE(logunit,*)'*********************************'
        END IF
     
     END DO

  END IF

END SUBROUTINE Write_Trials_Success

SUBROUTINE Write_Subroutine_Times

  IMPLICIT NONE

WRITE(logunit,*)
WRITE(logunit,*) 'Writing information about subroutine times'
WRITE(logunit,*)
WRITE(logunit,*) '******************************************'
WRITE(logunit,*)


IF(movetime(imove_trans) .GT. 0.0_DP ) THEN

   IF(movetime(imove_trans) .LT. 60.0_DP ) THEN 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Translation time = ', movetime(imove_trans), ' secs.'
   ELSE IF(movetime(imove_trans) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Translation time = ', movetime(imove_trans) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Translation time = ', movetime(imove_trans) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_rot) .GT. 0.0_DP ) THEN

   IF(movetime(imove_rot) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Rotation time = ', movetime(imove_rot), ' secs.'
   ELSE IF(movetime(imove_rot) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Rotation time = ', movetime(imove_rot) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Rotation time = ', movetime(imove_rot) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_dihedral) .GT. 0.0_DP ) THEN

   IF(movetime(imove_dihedral) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Dihedral time = ', movetime(imove_dihedral), ' secs.'
   ELSE IF(movetime(imove_dihedral) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Dihedral time = ', movetime(imove_dihedral) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Dihedral time = ', movetime(imove_dihedral) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_angle) .GT. 0.0_DP ) THEN

   IF(movetime(imove_angle) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Angle change time = ', movetime(imove_angle), ' secs.'
   ELSE IF(movetime(imove_angle) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Angle change time = ', movetime(imove_angle) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Angle change time = ', movetime(imove_angle) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_volume) .GT. 0.0_DP ) THEN

   IF(movetime(imove_volume) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Volume change time = ', movetime(imove_volume), ' secs.'
   ELSE IF(movetime(imove_volume) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Volume change time = ', movetime(imove_volume) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Volume change time = ', movetime(imove_volume) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_insert) .GT. 0.0_DP ) THEN

   IF(movetime(imove_insert) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Insertion time = ', movetime(imove_insert), ' secs.'
   ELSE IF(movetime(imove_insert) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Insertion time = ', movetime(imove_insert) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Insertion time = ', movetime(imove_insert) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_swap) .GT. 0.0_DP ) THEN

   IF(movetime(imove_swap) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Swap time = ', movetime(imove_swap), ' secs.'
   ELSE IF(movetime(imove_swap) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Swap time = ', movetime(imove_swap) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Swap time = ', movetime(imove_swap) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_delete) .GT. 0.0_DP ) THEN

   IF(movetime(imove_delete) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Deletion time = ', movetime(imove_delete), ' secs.'
   ELSE IF(movetime(imove_delete) .LT. 3600.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Deletion time = ', movetime(imove_delete) / 60.0_DP , ' mins.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Deletion time = ', movetime(imove_delete) / 3600.0_DP , ' hrs.'
   END IF

END IF


IF(movetime(imove_regrowth) .GT. 0.0_DP ) THEN

   IF(movetime(imove_regrowth) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Regrowth time = ', movetime(imove_regrowth), ' secs.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Regrowth time = ', movetime(imove_regrowth) / 3600.0_DP , ' hrs.'
   END IF

END IF

IF(movetime(imove_translate_cluster) .GT. 0.0_DP ) THEN

   IF(movetime(imove_translate_cluster) .LT. 60.0_DP ) THEN
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Cluster Move time = ', movetime(imove_translate_cluster), ' secs.'
   ELSE 
        WRITE(logunit,'(1X,A,T25,F15.6,A)') &
       'Cluster Move time = ', movetime(imove_translate_cluster) / 3600.0_DP , ' hrs.'
   END IF

END IF

END SUBROUTINE Write_Subroutine_Times

END MODULE Read_Write_Checkpoint

