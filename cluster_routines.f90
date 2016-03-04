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

MODULE Cluster_Routines

  !******************************************************************************
  ! 
  ! This module contains routines that identify clusters using a version of the 
  ! Hoshen-Kopelman algorithm.
  !
  ! - Andrew P. Santos
  !
  !*******************************************************************************

  USE Run_Variables
  USE Random_Generators

  IMPLICIT NONE

CONTAINS

  SUBROUTINE Find_Clusters(this_box)

    !*********************************************************************************
    !
    ! Hoshen-Kopelman algorithm for efficiently identifying clusters
    !
    ! 2/19/15  : Andrew P. Santos
    !*********************************************************************************

    INTEGER, INTENT(IN) :: this_box
    INTEGER :: tot_natoms, tot_nmol
    INTEGER :: imol, jmol, iatom, i, im, jm
    INTEGER :: is, js, is_clus, js_clus, start
    LOGICAL, ALLOCATABLE, DIMENSION(:) :: neigh_list
    INTEGER, ALLOCATABLE, DIMENSION(:,:) :: live_mol_index

    IF ( ALLOCATED(cluster%clabel) ) DEALLOCATE(cluster%clabel, cluster%N)

    ALLOCATE( live_mol_index(MAXVAL(nmols(:,this_box)), cluster%n_species_type) )

    live_mol_index = 0
    tot_nmol = 0
    DO is = 1, cluster%n_species_type
        is_clus = cluster%species_type(is)
        i = 1
        MoleculeLoop:DO imol = 1, nmolecules(is_clus)
            im = locate(imol, is_clus)
            ! Make sure that the molecule exists in the simulation
            IF( .NOT. molecule_list(im,is_clus)%live ) CYCLE MoleculeLoop
            live_mol_index(i,is_clus) = im
            i = i + 1
            tot_nmol = tot_nmol + 1
        END DO MoleculeLoop
    END DO

    IF (tot_nmol == 0) THEN
        RETURN
    END IF

    tot_natoms = SUM(natoms(:))

    cluster%clusmax = 0

    IF (cluster%criteria == int_com) THEN
        ! cluster label of labels
        ! counts how many atoms are in the cluster
        ALLOCATE(cluster%N(0:tot_nmol))
        ALLOCATE(cluster%clabel(MAXVAL(nmolecules(:)), cluster%n_species_type))
        cluster%N = 0
        cluster%clabel = 0
        DO is = 1, cluster%n_species_type
            is_clus = cluster%species_type(is)
            DO imol = 1, nmols(is_clus,this_box)
                !Get a list of the neighbors to an atom in the frame
                im = live_mol_index(imol,is)
                DO js = 1, cluster%n_species_type

                    js_clus = cluster%species_type(js)
                    IF (js_clus == is_clus) THEN
                        start = imol+1
                    ELSE
                        start = 1
                    END IF

                    ALLOCATE(neigh_list(nmolecules(js_clus)))
                    neigh_list = .FALSE.
                    DO jmol = start, nmols(js_clus,this_box)
                        jm = live_mol_index(jmol,is)
                        neigh_list(jm) = Neighbor(jm, im, js_clus, is_clus)
                    END DO

                    ! Update cluster label list
                    CALL Update_Labels(im, is_clus, js_clus, neigh_list)
                    DEALLOCATE(neigh_list)
                END DO

            END DO
        END DO
    END IF

    DO imol = 1, tot_nmol
        IF (cluster%N(imol) > 0) THEN
            cluster%M( cluster%N(imol) ) = cluster%M( cluster%N(imol) ) + 1
        END IF
    END DO

  END SUBROUTINE Find_Clusters

  SUBROUTINE Update_Labels(imol, is, js, neigh_list)

    !*********************************************************************************
    !
    ! Part of the Hoshen-Kopelman, where the labels of atoms/molecules in each cluster
    ! is updated
    !
    ! 2/19/15  : Andrew P. Santos
    !*********************************************************************************
    INTEGER, INTENT(IN) :: imol, is, js
    LOGICAL, INTENT(IN), DIMENSION(nmolecules(js)) :: neigh_list
    INTEGER :: iclus, nclus, ineigh
    INTEGER :: max_clus, min_clus

    DO ineigh = 1, nmolecules(js)
        IF (neigh_list(ineigh) == .FALSE.) CYCLE

        ! current site' cluster label
        iclus = cluster%clabel(imol, is)
        ! neighboring site's cluster label
        nclus = cluster%clabel(ineigh, js)
        ! IF the neighbor site has been assigned
        IF (nclus /= 0) THEN
            ! IF the current site has yet to be assigned
            IF (iclus == 0) THEN
                ! assign the cluster to the occupied neighbor's cluster
                cluster%clabel(imol, is) = nclus
                DO WHILE (cluster%N(nclus) < 0)
                    nclus = -cluster%N(nclus)
                END DO

                cluster%N(nclus) = cluster%N(nclus) + 1

            ! IF the current site is defined
            ELSE
                ! assign both labels with the larger value to the lower
                DO WHILE (cluster%N(nclus) < 0)
                    nclus = -cluster%N(nclus)
                END DO

                DO WHILE (cluster%N(iclus) < 0)
                    iclus = -cluster%N(iclus)
                END DO

                min_clus = min(nclus, iclus)
                max_clus = max(nclus, iclus)
                ! assign the cluster lower label value
                cluster%clabel(imol, is) = min_clus
                IF (min_clus /= max_clus) THEN
                    cluster%N(min_clus) = cluster%N(min_clus) + cluster%N(max_clus)
                    cluster%N(max_clus) = -min_clus
                END IF

            END IF

        ! IF the neighbor bead has not been assigned
        ELSE 
            ! IF the current site has yet to be assigned
            IF (iclus == 0) THEN
                ! assign site a new cluster label
                cluster%clusmax = cluster%clusmax + 1
                cluster%clabel(imol, is) = cluster%clusmax
                iclus = cluster%clusmax
                cluster%N(cluster%clusmax) = 1
            END IF

            cluster%clabel(ineigh, js) = iclus

            DO WHILE (cluster%N(iclus) < 0)
                iclus = -cluster%N(iclus)
            END DO

            cluster%N(iclus) = cluster%N(iclus) + 1
        END IF
    END DO

    IF (cluster%clabel(imol, is) == 0) THEN
        cluster%clusmax = cluster%clusmax + 1
        cluster%clabel(imol, is) = cluster%clusmax
        cluster%N(cluster%clusmax) = 1
    END IF

  END SUBROUTINE Update_Labels

  FUNCTION Neighbor(test_part, cur_part, test_type, cur_type)

    !*********************************************************************************
    !
    ! Return T/F if two atoms/molecules are neighbors
    !
    ! 2/19/15  : Andrew P. Santos
    !*********************************************************************************

    LOGICAL :: Neighbor, cluster_type
    INTEGER, INTENT(IN) :: test_part, cur_part, test_type, cur_type
    REAL(DP) :: rxij, ryij, rzij, rijsq, rxijp, ryijp, rzijp
    INTEGER :: itype
    
    Neighbor = .FALSE.

    IF (ANY(cluster%species_type /= test_type)) THEN
        RETURN
    END IF
      
    IF (cluster%criteria == int_com) THEN
        ! Get the positions of the COM of the two molecule species
        rxijp = molecule_list(test_part,test_type)%xcom - molecule_list(cur_part, cur_type)%xcom
        ryijp = molecule_list(test_part,test_type)%ycom - molecule_list(cur_part, cur_type)%ycom
        rzijp = molecule_list(test_part,test_type)%zcom - molecule_list(cur_part, cur_type)%zcom
        
        ! Now get the minimum image separation 
        CALL Minimum_Image_Separation(1, rxijp, ryijp, rzijp, rxij, ryij, rzij)

        rijsq = rxij*rxij + ryij*ryij + rzij*rzij
        
        IF (rijsq < cluster%min_distance_sq(test_type)) THEN
           Neighbor = .TRUE.
        END IF
                      
    END IF

  END FUNCTION Neighbor

END MODULE Cluster_Routines