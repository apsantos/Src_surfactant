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


!*************************************************************************
! The file contains three subroutines: 
!
!  Get_COM 
!  
!      This routine is used to compute the COM of a molecule
!
!  Get_Internal_Coordinates
!
!      This routine is used to determine values of intramolecular degrees
!      of freedom of a molecule
! 
!  Get_Max_COM_Distance
!
!      The routine calculates the distance between the COM and the atom
!      furthest to it
!
! Revision history
!
!   12/10/13  : Beta Release
!*************************************************************************

SUBROUTINE Get_COM(alive,is)
  !**********************************************************************
  ! compute the COM of the input molecule 'alive' of species is
  !
  ! CALLED BY
  !
  !        angle_distortion
  !        atom_displacement
  !        cutNgrow
  !        deletion
  !        fragment_growth
  !        gemc_particle_transfer
  !        grow_molecules
  !        insertion
  !        main
  !        read_write_checkpoint
  !        rigid_dihedral_change
  !        rotate
  !        zig_by_omega
  !
  ! CALLS
  !
  !        None
  !***********************************************************************
  USE Type_Definitions
  USE Run_Variables
  IMPLICIT NONE
  
  INTEGER, INTENT(IN) :: alive,is
  
  INTEGER :: k
  REAL(DP) :: total_mass, this_mass
  INTEGER :: cross_x, cross_y, cross_z, this_box
  REAL(DP) :: xcom_new, ycom_new, zcom_new, xcom_old, ycom_old, zcom_old
  this_box = 1

  total_mass = 0.0_DP
  
  molecule_list(alive,is)%xcom = 0.0_DP
  molecule_list(alive,is)%ycom = 0.0_DP
  molecule_list(alive,is)%zcom = 0.0_DP
  
  cross_x = 0
  cross_y = 0
  cross_z = 0
  DO k = 1, natoms(is)
     
     ! Peform this part only for atoms that exist in the simulation box.
     ! This allows to compute the COM of partially grown molecules
     
     IF  (atom_list(k,alive,is)%exist) THEN
        
        this_mass = nonbond_list(k,is)%mass
        
        total_mass = total_mass + this_mass
        
        molecule_list(alive,is)%xcom = molecule_list(alive,is)%xcom + this_mass * &
             atom_list(k,alive,is)%rxp
        molecule_list(alive,is)%ycom = molecule_list(alive,is)%ycom + this_mass * &
             atom_list(k,alive,is)%ryp
        molecule_list(alive,is)%zcom = molecule_list(alive,is)%zcom + this_mass * &
             atom_list(k,alive,is)%rzp

        ! If this is the 2nd or later atom in a molecule
        IF (k > 1) THEN
           ! If we do not know if the molecule been wrapped
           IF ( cross_x == 0) THEN
              ! The molecule is wrapped
              IF ( ABS(atom_list(k,alive,is)%rxp - atom_list(k-1,alive,is)%rxp) > &
                   box_list(1)%hlength(1,1) ) THEN
                 ! The kth atom is greater than the center
                 IF ( atom_list(k,alive,is)%rxp > 0) THEN
                    cross_x = 1
                 ! The kth atom is less than the center
                 ELSE
                    cross_x = -1
                 END IF
              END IF
           END IF
           IF ( cross_y == 0) THEN
              IF ( ABS(atom_list(k,alive,is)%ryp - atom_list(k-1,alive,is)%ryp) > &
                   box_list(1)%hlength(2,2) ) THEN
                 IF ( atom_list(k,alive,is)%ryp > 0) THEN
                    cross_y = 1
                 ELSE
                    cross_y = -1
                 END IF
              END IF
           END IF
           IF ( cross_z == 0) THEN
              IF ( ABS(atom_list(k,alive,is)%rzp - atom_list(k-1,alive,is)%rzp) > &
                   box_list(1)%hlength(3,3) ) THEN
                 IF ( atom_list(k,alive,is)%rzp > 0) THEN
                    cross_z = 1
                 ELSE
                    cross_z = -1
                 END IF
              END IF
           END IF
           ! IF part of the the molecule has wrapped around PBC
           ! in the x-, y- or z-direction
           IF ( cross_x == 1 ) THEN
              ! if the position of x > 0 and it has been wrapped in that direction,
              ! send them back to the otherside, which will be outside of the box
              IF ( atom_list(k,alive,is)%rxp > 0) THEN
                 molecule_list(alive,is)%xcom = molecule_list(alive,is)%xcom - &
                                                this_mass * box_list(1)%length(1,1)
              END IF
           ELSE IF ( cross_x == -1 ) THEN
              IF ( atom_list(k,alive,is)%rxp < 0) THEN
                 molecule_list(alive,is)%xcom = molecule_list(alive,is)%xcom + &
                                                this_mass * box_list(1)%length(1,1)
              END IF
           END IF
           IF ( cross_y == 1 ) THEN
              IF ( atom_list(k,alive,is)%ryp > 0) THEN
              molecule_list(alive,is)%ycom = molecule_list(alive,is)%ycom - &
                                  this_mass * box_list(1)%length(2,2)
              END IF
           ELSE IF ( cross_y == -1 ) THEN
              IF ( atom_list(k,alive,is)%ryp < 0) THEN
              molecule_list(alive,is)%ycom = molecule_list(alive,is)%ycom + &
                                  this_mass * box_list(1)%length(2,2)
              END IF
           END IF
           IF ( cross_z == 1 ) THEN
              IF ( atom_list(k,alive,is)%rzp > 0) THEN
              molecule_list(alive,is)%zcom = molecule_list(alive,is)%zcom - &
                                  this_mass * box_list(1)%length(3,3)
              END IF
           ELSE IF ( cross_z == -1 ) THEN
              IF ( atom_list(k,alive,is)%rzp < 0) THEN
              molecule_list(alive,is)%zcom = molecule_list(alive,is)%zcom + &
                                  this_mass * box_list(1)%length(3,3)
              END IF
           END IF
        END IF

     END IF
     
  END DO
  
  molecule_list(alive,is)%xcom = molecule_list(alive,is)%xcom / total_mass
  molecule_list(alive,is)%ycom = molecule_list(alive,is)%ycom / total_mass
  molecule_list(alive,is)%zcom = molecule_list(alive,is)%zcom / total_mass

  ! If the final center of mass of a split molecule is outside of the box, use PBC to put it back in
  IF ( cross_x /= 0 .or. cross_y /= 0 .or. cross_z /= 0) THEN
     xcom_old = molecule_list(alive,is)%xcom
     ycom_old = molecule_list(alive,is)%ycom
     zcom_old = molecule_list(alive,is)%zcom
     CALL Apply_PBC_Anint(this_box,xcom_old,ycom_old,zcom_old, xcom_new, ycom_new, zcom_new)
     molecule_list(alive,is)%xcom = xcom_new
     molecule_list(alive,is)%ycom = ycom_new
     molecule_list(alive,is)%zcom = zcom_new
  END IF

END SUBROUTINE Get_COM


SUBROUTINE Get_Internal_Coordinates(alive,ispecies)

  !************************************************************************
  ! Computes the internal coordinates of a molecule
  ! 
  ! CALLED BY
  !
  !   angle_distortion
  !   cutNgrow
  !   rigid_dihedral_change
  !   nvt_mc_fragment_driver
  !
  ! CALLS
  !
  !    Get_Bond_Length
  !    Get_Bond_Angle
  !    Get_Dihedral_Angle
  !    Get_Improper_Angle
  !
  !
  !***********************************************************************
  
  USE Type_Definitions
  USE Run_Variables
  
  IMPLICIT NONE
  
  INTEGER, INTENT(IN) :: alive, ispecies
  !--------------------------------------------------------------------------------------------
  
  INTEGER :: ibonds, iangles, idihedrals, iimpropers
  REAL(DP) :: bond_length, theta, phi
  
  DO ibonds = 1, nbonds(ispecies)
     
     CALL Get_Bond_Length(ibonds,alive,ispecies, bond_length)
     
       ! Assign the bond length to the internal coordinate
     
     internal_coord_list(ibonds,alive,ispecies)%bond_length_angstrom = &
          bond_length
     
  END DO
  
  DO iangles = 1, nangles(ispecies)
     
     CALL Get_Bond_Angle(iangles,alive,ispecies,theta)
     
     ! Assign this angle to internal_coord_list
     
     internal_coord_list(iangles,alive,ispecies)%bond_angle_radians = &
          theta
     
     ! Convert the angle into degrees
     
     internal_coord_list(iangles,alive,ispecies)%bond_angle_degrees = &
          theta * 180.0 / PI
     
  END DO
  
  DO idihedrals = 1, ndihedrals(ispecies)
     
     CALL Get_Dihedral_Angle(idihedrals,alive,ispecies,phi)
     
     ! Assign this value to the internal_coord_list
     
     internal_coord_list(idihedrals,alive,ispecies)%dihedral_angle_radians &
          = phi
     
     ! Convert the angle into degrees
     
     internal_coord_list(idihedrals,alive,ispecies)%dihedral_angle_degrees &
          = phi * 180.0 / PI
     
  END DO
  
  DO iimpropers = 1, nimpropers(ispecies)
     
     CAll Get_Improper_Angle(iimpropers,alive,ispecies,phi)
     
     ! Assign this value to the internal_coord_list
     
     internal_coord_list(iimpropers,alive,ispecies)%improper_angle_radians &
          = phi
     
     ! Convert the angle into degrees
     
     internal_coord_list(iimpropers,alive,ispecies)%improper_angle_degrees &
          = phi * 180.0 / PI
       
  END DO
  
END SUBROUTINE Get_Internal_Coordinates
!******************************************************************************

SUBROUTINE Compute_Max_COM_Distance(alive,is)

  !*****************************************************************************
  ! The program is used to compute the maximum distance of any psuedoatom from
  ! the COM of the molecule. 
  !
  ! The routine will be called at the beginning of a simulation and whenever
  ! a conformational change is observed in a given molecule.
  !
  !*****************************************************************************

  USE Run_Variables

  IMPLICIT NONE

  INTEGER, INTENT(IN) :: alive, is

  ! Local variables

  REAL(DP) :: xcom, ycom, zcom, dmax, dx, dy, dz, rsq

  INTEGER :: iatom

  
  ! obtain the com of the molecule

  xcom = molecule_list(alive,is)%xcom
  ycom = molecule_list(alive,is)%ycom
  zcom = molecule_list(alive,is)%zcom

  ! set the maximum distanc initially to zero

  dmax = 0.0_DP

  DO iatom = 1,natoms(is)

     ! check to see if the atoms exist. This condition is necessary
     ! to be able to compute the COM of a partially grown molecule.

     IF(atom_list(iatom,alive,is)%exist) THEN
        
        dx = atom_list(iatom,alive,is)%rxp - xcom
        dy = atom_list(iatom,alive,is)%ryp - ycom
        dz = atom_list(iatom,alive,is)%rzp - zcom
        
        ! No need to apply periodic boundary conditions 
        
        rsq = dx * dx + dy * dy + dz * dz
        
        dmax = MAX(dmax,rsq)

     END IF

  END DO

  ! store the maximum distance 

  molecule_list(alive,is)%max_dcom = DSQRT(dmax)

END SUBROUTINE Compute_Max_COM_Distance
     

  

    
