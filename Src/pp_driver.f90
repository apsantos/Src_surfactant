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

SUBROUTINE PP_Driver
  !****************************************************************************
  !
  ! The subroutine performs Post Processing
  ! 
  ! Called by
  !
  !   main.f90
  !
  ! Revision history
  !
  !   12/10/13 : Beta Release
!*******************************************************************************

  USE Run_Variables
  USE File_Names
  USE Energy_Routines
  USE Read_Write_Checkpoint
  USE Cluster_Routines
  USE Excluded_Volume
  USE Degree_Association
  USE Measure_Molecules
  USE Transport_Properties

  IMPLICIT NONE

!  !$ include 'omp_lib.h'

  INTEGER :: i, this_box, ibox, is

  REAL(DP) :: time_start

  LOGICAL :: overlap, complete, lopen

  LOGICAL, DIMENSION(:), ALLOCATABLE :: next_write, next_rdf_write

  ALLOCATE(next_write(nbr_boxes))
  ALLOCATE(next_rdf_write(nbr_boxes))
  next_write(:) = .false.
  next_rdf_write(:) = .false.
  complete = .FALSE.
  lopen = .FALSE.
 
  this_box = 1

  IF(.NOT. openmp_flag) THEN
     CALL cpu_time(time_start)
  ELSE
!$  time_start = omp_get_wtime()
  END IF

  i = 0

  DO WHILE (.NOT. complete)

     i = i + 1

     IF (i == n_mcsteps) complete = .TRUE.

     IF ( start_type == 'read_xyz' ) THEN
        IF (i > 1) THEN
           CALL Read_XYZ(i)
        ENDIF
        INQUIRE(file=xyz_config_file(this_box),opened=lopen)
     ELSEIF (start_type == 'read_gro' ) THEN
        IF (i > 1) THEN
           CALL Read_GRO(i)
        ENDIF
        INQUIRE(file=gro_config_file,opened=lopen)
     ELSEIF (start_type == 'read_xtc' ) THEN
        IF (i > 1) THEN
           CALL Read_XTC(i)
        ENDIF
        lopen = .true.
     ELSEIF (start_type == 'read_dcd' ) THEN
        IF (i > 1) THEN
           CALL Read_DCD(i)
        ENDIF
        lopen = .true.
     ENDIF
 
     IF (.not. lopen) THEN
        WRITE(*,*) 'Only, '//TRIM(Int_To_String(i-1))//', steps in config file'
        IF (i < n_equilsteps) THEN
            WRITE(*,*) 'Too many equil steps given'
        ELSE
            WRITE(*,*) 'Too many steps given'
        END IF
        complete = .TRUE.
        nthermo_freq = 0
     ENDIF

     next_write(this_box) = .true.
     next_rdf_write(this_box) = .true.

     ! We will select a move from Golden Sampling scheme
  
     IF (i < n_equilsteps) CYCLE

     !IF (read_volume .AND. MOD(i-1,ivolfreq) /= 0) CYCLE

     CALL Accumulate(this_box)
     
     IF ( .NOT. block_average ) THEN

        ! instantaneous values are to be printed   

        IF ( ncoord_freq /= 0 ) THEN
           IF ( MOD(i,ncoord_freq) == 0 ) THEN
              
              DO ibox = 1, nbr_boxes
                 
                 CALL Write_Coords(ibox)
                 
              END DO
              
           END IF
        END IF

        IF ( ncluster_freq /= 0 ) THEN
           IF ( MOD(i,ncluster_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
              
                 CALL Find_Clusters(ibox,1)
                 CALL Write_Cluster(ibox)
              
              END DO
           
              !CALL cpu_time(now_time)
              !print '("clus Time = ",f6.3," seconds.")',now_time-time_start
           END IF
        END IF
        
        IF ( ncluslife_freq /= 0 ) THEN
           IF ( MOD(i,ncluslife_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
                 IF ( MOD(i,ncluster_freq) /= 0 ) THEN
                    CALL Find_Clusters(ibox,1)
                 END IF
                 IF ( i == 0) THEN
                    cluster%clabel = cluster%clabel_prev
                    cluster%N = cluster%N_prev
                 ENDIF
              
                 CALL Update_Cluster_Life
                 CALL Write_Cluster(ibox)
                 IF ( ncoord_freq /= 0 ) THEN
                    IF ( MOD(i,ncoord_freq) == 0 ) THEN
                        CALL Write_Cluster_Color(ibox)
                    END IF
                 END IF
              
              !CALL cpu_time(now_time)
              !print '("exvol Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF

        IF ( noligdist_freq /= 0 ) THEN
           IF ( MOD(i,noligdist_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
                 IF ( MOD(i,ncluster_freq) /= 0 ) THEN
                    CALL Find_Clusters(ibox,1)
                 END IF
              
                 CALL Calculate_Oligomer_NN_Distance(ibox)
              
              !CALL cpu_time(now_time)
              !print '("exvol Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF

        IF ( nalpha_freq /= 0 ) THEN
           IF ( MOD(i,nalpha_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
                 IF ( MOD(i,ncluster_freq) /= 0 ) THEN
                    CALL Find_Clusters(ibox,1)
                 END IF
              
                 CALL Calculate_Degree_Association
                 CALL Write_Cluster(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( nexvol_freq /= 0 ) THEN
           IF ( MOD(i,nexvol_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
                 CALL Find_Clusters(ibox,3)
              
                 CALL Calculate_Excluded_Volume(ibox)

                 CALL Find_Clusters(ibox,1)

              !CALL cpu_time(now_time)
              !print '("exvol Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF

        IF ( nmsd_freq /= 0 ) THEN
           IF ( MOD(i,nmsd_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
              
                 CALL Calculate_MSD()
                 CALL Write_MSD(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF

        IF ( nvacf_freq /= 0 ) THEN
           IF ( MOD(i,nvacf_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
              
                 CALL Calculate_VACF()
                 CALL Write_VACF(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF

        IF ( nendclus_freq /= 0 ) THEN
           IF ( MOD(i,nendclus_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes
                 IF ( MOD(i,ncluster_freq) /= 0 ) THEN
                    CALL Find_Clusters(ibox,1)
                 END IF
              
                 CALL Calculate_End_To_End_Distance()
                 CALL Write_Cluster(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( nbond_freq /= 0 ) THEN
           IF ( MOD(i,nbond_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes

                 CALL Calculate_Bond_his()
                 CALL Write_Bond(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( nangle_freq /= 0 ) THEN
           IF ( MOD(i,nangle_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes

                 CALL Calculate_Angle_his()
                 CALL Write_Angle(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( ndihedral_freq /= 0 ) THEN
           IF ( MOD(i,ndihedral_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes

                 CALL Calculate_Dihedral_his()
                 CALL Write_Dihedral(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( natomdist_freq /= 0 ) THEN
           IF ( MOD(i,natomdist_freq) == 0 ) THEN
              !CALL cpu_time(time_start)
           
              DO ibox = 1, nbr_boxes

                 CALL Calculate_Atom_Distribution()
                 CALL Write_Atom_Distribution(ibox)
              
              !CALL cpu_time(now_time)
              !print '("alpha Time = ",f6.3," seconds.")',now_time-time_start
              END DO
           
           END IF
        END IF
        
        IF ( nthermo_freq /= 0) THEN
           IF ( MOD(i,nthermo_freq) == 0) THEN
   
              DO ibox = 1, nbr_boxes
              
                 CALL Write_Properties(i,ibox)
                 CALL Reset(ibox)
                 
              END DO
              
           END IF
        END IF
        
     ELSE
        
        DO ibox = 1, nbr_boxes
           
           IF (tot_trials(ibox) /= 0) THEN
              IF(MOD(tot_trials(ibox),nthermo_freq) == 0) THEN
                 IF (next_write(ibox)) THEN
                    CALL Write_Properties(tot_trials(ibox),ibox)
                    CALL Reset(ibox)
                    next_write(ibox) = .false.
                 END IF
              END IF
              
              IF (MOD(tot_trials(ibox), ncoord_freq) == 0) THEN
                 IF (next_rdf_write(ibox)) THEN
                    CALL Write_Coords(ibox)
                    next_rdf_write(ibox) = .false.
                 END IF
              END IF
              
           END IF
           
        END DO
     
     END IF

     IF ( ncoord_freq /= 0 ) THEN
        IF(MOD(i,ncoord_freq) == 0) THEN
           CALL Write_Checkpoint(i)
        END IF
     END IF

     DO is = 1,nspecies

        IF(species_list(is)%int_insert == int_igas) THEN
           IF(mod(i,n_igas_moves(is)) == 0) CALL Update_Reservoir(is)
        END IF

     END DO
     
  END DO

  CLOSE(50)

  ! let us check if at the end of the simulation, the energies are properly updated

  write(logunit,*) '*********** Ending simulation *****************'
  write(logunit,*)
  write(logunit,*)

    ! Display the components of the energy.
  WRITE(logunit,*) '*****************************************'
  WRITE(logunit,'(A36,2X,I2)') ' Starting energy components for box', this_box
  WRITE(logunit,*) ' Atomic units-Extensive'
  WRITE(logunit,*) '*****************************************'
  WRITE(logunit,*)

  write(logunit,'(A,T30,F20.3)') 'Total system energy is' , energy(this_box)%total
  write(logunit,'(A,T30,F20.3)') 'Intra molecular energy is', energy(this_box)%intra
  write(logunit,'(A,T30,F20.3)') 'Bond energy is', energy(this_box)%bond
  write(logunit,'(A,T30,F20.3)') 'Angle energy is', energy(this_box)%angle
  write(logunit,'(A,T30,F20.3)') 'Dihedral enregy is', energy(this_box)%dihedral
  WRITE(logunit,'(A,T30,F20.3)') 'Improper angle energy is', energy(this_box)%improper
  write(logunit,'(A,T30,F20.3)') 'Intra nonbond vdw is', energy(this_box)%intra_vdw
  write(logunit,'(A,T30,F20.3)') 'Intra nonbond elec is', energy(this_box)%intra_q
  write(logunit,'(A,T30,F20.3)') 'Inter molecule vdw is', energy(this_box)%inter_vdw
  write(logunit,'(A,T30,F20.3)') 'Long range correction is', energy(this_box)%lrc
  write(logunit,'(A,T30,F20.3)') 'Inter molecule q is', energy(this_box)%inter_q
  write(logunit,'(A,T30,F20.3)') 'Reciprocal ewald is', energy(this_box)%ewald_reciprocal
  write(logunit,'(A,T30,F20.3)') 'Self ewald is', energy(this_box)%ewald_self
  
  write(logunit,*) '**************************************************'


  CALL Compute_Total_System_Energy(this_box,.TRUE.,overlap)

    ! Display the components of the energy.
  write(logunit,*)
  write(logunit,*)
  WRITE(logunit,*) '*****************************************'
  write(logunit,'(A52,2X,I2)') 'Components of energy from total energy call for box', this_box
  WRITE(logunit,*) 'Atomic units-Extensive'
  WRITE(logunit,*) '*****************************************'
  WRITE(logunit,*)

  write(logunit,'(A,T30,F20.3)') 'Total system energy is' , energy(this_box)%total
  write(logunit,'(A,T30,F20.3)') 'Intra molecular energy is', energy(this_box)%intra
  write(logunit,'(A,T30,F20.3)') 'Bond energy is', energy(this_box)%bond
  write(logunit,'(A,T30,F20.3)') 'Angle energy is', energy(this_box)%angle
  write(logunit,'(A,T30,F20.3)') 'Dihedral enregy is', energy(this_box)%dihedral
  WRITE(logunit,'(A,T30,F20.3)') 'Improper angle energy is', energy(this_box)%improper
  write(logunit,'(A,T30,F20.3)') 'Intra nonbond vdw is', energy(this_box)%intra_vdw
  write(logunit,'(A,T30,F20.3)') 'Intra nonbond elec is', energy(this_box)%intra_q
  write(logunit,'(A,T30,F20.3)') 'Inter molecule vdw is', energy(this_box)%inter_vdw
  write(logunit,'(A,T30,F20.3)') 'Long range correction is', energy(this_box)%lrc
  write(logunit,'(A,T30,F20.3)') 'Inter molecule q is', energy(this_box)%inter_q
  write(logunit,'(A,T30,F20.3)') 'Reciprocal ewald is', energy(this_box)%ewald_reciprocal
  write(logunit,'(A,T30,F20.3)') 'Self ewald is', energy(this_box)%ewald_self

  IF(int_run_style == run_test) THEN

    OPEN(75,FILE='compare.dat',POSITION='APPEND')
    WRITE(75,"(T20,A,A)") testname, 'in the gcmc ensemble'
    WRITE(75,"(A,F24.12)") 'The total system energy is:', energy(1)%total
    WRITE(75,"(A,I10)") 'The total number of molecules is:', nmols(1,1)
    WRITE(75,*)
    CLOSE(75)

  END IF

  IF ( start_type == 'read_xyz' ) THEN
    CLOSE(unit=xyz_config_unit(1))
  ELSEIF (start_type == 'read_gro' ) THEN
    CLOSE(unit=gro_config_unit)
  ELSEIF (start_type == 'read_dcd' ) THEN
    CLOSE(unit=dcd_config_unit)
  ENDIF

  IF (read_volume) THEN
    CLOSE(unit=volume_info_unit)
  ENDIF

  END SUBROUTINE PP_Driver
