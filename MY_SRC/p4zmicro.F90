MODULE p4zmicro
   !!======================================================================
   !!                         ***  MODULE p4zmicro  ***
   !! TOP :   PISCES Compute the sources/sinks for microzooplankton
   !!======================================================================
   !! History :   1.0  !  2004     (O. Aumont) Original code
   !!             2.0  !  2007-12  (C. Ethe, G. Madec)  F90
   !!             3.4  !  2011-06  (O. Aumont, C. Ethe) Quota model for iron
   !!----------------------------------------------------------------------
   !!   p4z_micro      : Compute the sources/sinks for microzooplankton
   !!   p4z_micro_init : Initialize and read the appropriate namelist
   !!----------------------------------------------------------------------
   USE oce_trc         ! shared variables between ocean and passive tracers
   USE trc             ! passive tracers common variables 
   USE sms_pisces      ! PISCES Source Minus Sink variables
   USE p4zlim          ! Co-limitations
   USE p4zprod         ! production
   USE iom             ! I/O manager
   USE prtctl_trc      ! print control for debugging

   IMPLICIT NONE
   PRIVATE

   PUBLIC   p4z_micro         ! called in p4zbio.F90
   PUBLIC   p4z_micro_init    ! called in trcsms_pisces.F90

   REAL(wp), PUBLIC ::   part        !: part of calcite not dissolved in microzoo guts
   REAL(wp), PUBLIC ::   xprefc      !: microzoo preference for POC 
   REAL(wp), PUBLIC ::   xprefn      !: microzoo preference for nanophyto
   REAL(wp), PUBLIC ::   xprefd      !: microzoo preference for diatoms
   REAL(wp), PUBLIC ::   xthreshdia  !: diatoms feeding threshold for microzooplankton 
   REAL(wp), PUBLIC ::   xthreshphy  !: nanophyto threshold for microzooplankton 
   REAL(wp), PUBLIC ::   xthreshpoc  !: poc threshold for microzooplankton 
   REAL(wp), PUBLIC ::   xthresh     !: feeding threshold for microzooplankton 
   REAL(wp), PUBLIC ::   resrat      !: exsudation rate of microzooplankton
   REAL(wp), PUBLIC ::   mzrat       !: microzooplankton mortality rate 
   REAL(wp), PUBLIC ::   grazrat     !: maximal microzoo grazing rate
   REAL(wp), PUBLIC ::   xkgraz      !: Half-saturation constant of assimilation
   REAL(wp), PUBLIC ::   unass       !: Non-assimilated part of food
   REAL(wp), PUBLIC ::   sigma1      !: Fraction of microzoo excretion as DOM 
   REAL(wp), PUBLIC ::   epsher      !: growth efficiency for grazing 1 
   REAL(wp), PUBLIC ::   epshermin   !: minimum growth efficiency for grazing 1

   !!----------------------------------------------------------------------
   !! NEMO/TOP 4.0 , NEMO Consortium (2018)
   !! $Id: p4zmicro.F90 10374 2018-12-06 09:49:35Z cetlod $ 
   !! Software governed by the CeCILL license (see ./LICENSE)
   !!----------------------------------------------------------------------
CONTAINS

   SUBROUTINE p4z_micro( kt, knt )
      !!---------------------------------------------------------------------
      !!                     ***  ROUTINE p4z_micro  ***
      !!
      !! ** Purpose :   Compute the sources/sinks for microzooplankton
      !!
      !! ** Method  : - ???
      !!---------------------------------------------------------------------
      INTEGER, INTENT(in) ::   kt    ! ocean time step
      INTEGER, INTENT(in) ::   knt   ! ??? 
      !
      INTEGER  :: ji, jj, jk
      REAL(wp) :: zcompadi, zcompaz , zcompaph, zcompapoc
      REAL(wp) :: zgraze  , zdenom, zdenom2
      REAL(wp) :: zfact   , zfood, zfoodlim, zbeta
      REAL(wp) :: zepsherf, zepshert, zepsherq, zepsherv, zgrarsig, zgraztotc, zgraztotn, zgraztotf
      REAL(wp) :: zgrarem, zgrafer, zgrapoc, zprcaca, zmortz
      REAL(wp) :: zrespz, ztortz, zgrasrat, zgrasratn
      REAL(wp) :: zgrazp, zgrazm, zgrazsd
      REAL(wp) :: zgrazmf, zgrazsf, zgrazpf
      REAL(wp), DIMENSION(jpi,jpj,jpk) :: zgrazing, zfezoo
      REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: zw3d, zzligprod
      CHARACTER (len=25) :: charout
!Cam Copper model
      REAL(wp) :: zgrazcu, zepshercu, zgrasratcu, zgrazmfcu, zepsherqcu, zgrazsfcu, zgrazpfcu
      REAL(wp) :: zgraztotfcu, zepshertcu
      REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: zcuzoo
!Zn model
      REAL(wp) :: zgrazzn, zepsherz, zgrasratz, zgrazmfz, zgrazsfz, zgrazpfz
      REAL(wp) :: zgraztotfz, zepshertz, zepsherqz
      REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: zznzoo
! Co Model
      REAL(wp) :: zgrazco, zepsherc, zgrasratc, zepsherqc, zgrazmfc, zgrazsfc, zgrazpfc
      REAL(wp) :: zgraztotfc, zepshertc
      REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: zcozoo
! Mn Model
      REAL(wp) :: zgrazmn, zepsherm, zgrasratm, zgrazmfm, zepsherqm,zgrazsfm, zgrazpfm
      REAL(wp) :: zgraztotfm, zepshertm
      REAL(wp), DIMENSION(:,:,:), ALLOCATABLE :: zmnzoo
!
      !!---------------------------------------------------------------------
      !
      IF( ln_timing )   CALL timing_start('p4z_micro')
      !
IF (ln_copper) THEN 
ALLOCATE(zcuzoo(jpi,jpj,jpk))
zcuzoo(:,:,:) = 0._wp
ENDIF
IF (ln_zinc) THEN
ALLOCATE(zznzoo(jpi,jpj,jpk))
zznzoo(:,:,:) = 0._wp
ENDIF
IF (ln_cobalt) THEN
ALLOCATE(zcozoo(jpi,jpj,jpk))
zcozoo(:,:,:) = 0._wp
ENDIF
IF (ln_manganese) THEN
ALLOCATE(zmnzoo(jpi,jpj,jpk))
zmnzoo(:,:,:) = 0._wp
ENDIF

      IF (ln_ligand) THEN
         ALLOCATE( zzligprod(jpi,jpj,jpk) )
         zzligprod(:,:,:) = 0._wp
      ENDIF
      !
      DO jk = 1, jpkm1
         DO jj = 1, jpj
            DO ji = 1, jpi
               zcompaz = MAX( ( trb(ji,jj,jk,jpzoo) - 1.e-9 ), 0.e0 )
               zfact   = xstep * tgfunc2(ji,jj,jk) * zcompaz

               !  Respiration rates of both zooplankton
               !  -------------------------------------
               zrespz = resrat * zfact * trb(ji,jj,jk,jpzoo) / ( xkmort + trb(ji,jj,jk,jpzoo) )  &
                  &   + resrat * zfact * 3. * nitrfac(ji,jj,jk)

               !  Zooplankton mortality. A square function has been selected with
               !  no real reason except that it seems to be more stable and may mimic predation.
               !  ---------------------------------------------------------------
               ztortz = mzrat * 1.e6 * zfact * trb(ji,jj,jk,jpzoo) * (1. - nitrfac(ji,jj,jk))

               zcompadi  = MIN( MAX( ( trb(ji,jj,jk,jpdia) - xthreshdia ), 0.e0 ), xsizedia )
               zcompaph  = MAX( ( trb(ji,jj,jk,jpphy) - xthreshphy ), 0.e0 )
               zcompapoc = MAX( ( trb(ji,jj,jk,jppoc) - xthreshpoc ), 0.e0 )
               
               !     Microzooplankton grazing
               !     ------------------------
               zfood     = xprefn * zcompaph + xprefc * zcompapoc + xprefd * zcompadi
               zfoodlim  = MAX( 0. , zfood - min(xthresh,0.5*zfood) )
               zdenom    = zfoodlim / ( xkgraz + zfoodlim )
               zdenom2   = zdenom / ( zfood + rtrn )
               zgraze    = grazrat * xstep * tgfunc2(ji,jj,jk) * trb(ji,jj,jk,jpzoo) * (1. - nitrfac(ji,jj,jk))

               zgrazp    = zgraze  * xprefn * zcompaph  * zdenom2 
               zgrazm    = zgraze  * xprefc * zcompapoc * zdenom2 
               zgrazsd   = zgraze  * xprefd * zcompadi  * zdenom2 

               zgrazpf   = zgrazp  * trb(ji,jj,jk,jpnfe) / (trb(ji,jj,jk,jpphy) + rtrn)
               zgrazmf   = zgrazm  * trb(ji,jj,jk,jpsfe) / (trb(ji,jj,jk,jppoc) + rtrn)
               zgrazsf   = zgrazsd * trb(ji,jj,jk,jpdfe) / (trb(ji,jj,jk,jpdia) + rtrn)
               !
               zgraztotc = zgrazp  + zgrazm  + zgrazsd 
               zgraztotf = zgrazpf + zgrazsf + zgrazmf 
               zgraztotn = zgrazp * quotan(ji,jj,jk) + zgrazm + zgrazsd * quotad(ji,jj,jk)
               IF (ln_copper) THEN
               zgrazpfcu   = zgrazp  * trb(ji,jj,jk,jpcun) / (trb(ji,jj,jk,jpphy) + rtrn)
               zgrazmfcu   = zgrazm  * trb(ji,jj,jk,jpcup) / (trb(ji,jj,jk,jppoc) + rtrn)
               zgrazsfcu   = zgrazsd * trb(ji,jj,jk,jpcud) / (trb(ji,jj,jk,jpdia) + rtrn)
               zgraztotfcu = zgrazpfcu + zgrazsfcu + zgrazmfcu
               ENDIF
               IF (ln_zinc) THEN
               zgrazpfz   = zgrazp  * trb(ji,jj,jk,jpznn) / (trb(ji,jj,jk,jpphy) + rtrn)
               zgrazmfz   = zgrazm  * trb(ji,jj,jk,jpznp) / (trb(ji,jj,jk,jppoc)+ rtrn)
               zgrazsfz   = zgrazsd * trb(ji,jj,jk,jpznd) / (trb(ji,jj,jk,jpdia) + rtrn)
               zgraztotfz = zgrazpfz + zgrazsfz + zgrazmfz
               ENDIF
               IF (ln_cobalt) THEN
               zgrazpfc   = zgrazp  * trb(ji,jj,jk,jpcon) / (trb(ji,jj,jk,jpphy) + rtrn)
               zgrazmfc   = zgrazm  * trb(ji,jj,jk,jpcop) / (trb(ji,jj,jk,jppoc) + rtrn)
               zgrazsfc   = zgrazsd * trb(ji,jj,jk,jpcod) / (trb(ji,jj,jk,jpdia) + rtrn)
               zgraztotfc = zgrazpfc + zgrazsfc + zgrazmfc
               ENDIF
               IF (ln_manganese) THEN
               zgrazpfm   = zgrazp  * trb(ji,jj,jk,jpmnn) / (trb(ji,jj,jk,jpphy) + rtrn)
               zgrazmfm   = zgrazm  * trb(ji,jj,jk,jpmnp) / (trb(ji,jj,jk,jppoc) + rtrn)
               zgrazsfm   = zgrazsd * trb(ji,jj,jk,jpmnd) / (trb(ji,jj,jk,jpdia) + rtrn)
               zgraztotfm = zgrazpfm + zgrazsfm + zgrazmfm
               ENDIF

               ! Grazing by microzooplankton
               zgrazing(ji,jj,jk) = zgraztotc

               !    Various remineralization and excretion terms
               !    --------------------------------------------
               zgrasrat  = ( zgraztotf + rtrn ) / ( zgraztotc + rtrn )
               zgrasratn = ( zgraztotn + rtrn ) / ( zgraztotc + rtrn )
               zepshert  =  MIN( 1., zgrasratn, zgrasrat / ferat3)
               zbeta     = MAX(0., (epsher - epshermin) )
               zepsherf  = epshermin + zbeta / ( 1.0 + 0.04E6 * 12. * zfood * zbeta )
               zepsherq  = 0.5 + (1.0 - 0.5) * zepshert * ( 1.0 + 1.0 ) / ( zepshert + 1.0 )
               zepsherv  = zepsherf * zepshert * zepsherq
!              zepsherv  = zepshert * MIN( zepsherf, (1. - unass) * zgrasrat /ferat3, (1. - unass) * zgrasratn )

               zgrafer   = zgraztotc * MAX( 0. , ( 1. - unass ) * zgrasrat - ferat3 * zepsherv ) 
               zgrarem   = zgraztotc * ( 1. - zepsherv - unass )
               zgrapoc   = zgraztotc * unass
              IF (ln_copper) THEN
              zgrasratcu  = ( zgraztotfcu + rtrn ) / ( zgraztotc + rtrn ) !Cam Cu:C of microzzoplankton preys
              zepshertcu  = MIN( 1., zgrasratn, zgrasratcu / ( curat3 ) )
               zepsherqcu  = 0.5 + (1.0 - 0.5) * zepshertcu * ( 1.0 + 1.0 ) / ( zepshertcu + 1.0 )
               zepshercu  = zepsherf * zepshertcu * zepsherqcu
!              zepshercu  = zepshertcu * MIN( epsher, (1. - unass) * zgrasratcu / ( curat3 ) , (1. - unass) * zgrasratn )
              zgrazcu   = zgraztotc * MAX( 0. , ( 1. - unass ) * zgrasratcu - ( curat3 ) * zepshercu )
              ENDIF
               IF (ln_zinc) THEN
              zgrasratz  = ( zgraztotfz + rtrn ) / ( zgraztotc + rtrn )
              zepshertz  = MIN( 1., zgrasratn, zgrasratz / znrat3)
               zepsherqz  = 0.5 + (1.0 - 0.5) * zepshertz * ( 1.0 + 1.0 ) / ( zepshertz + 1.0 )
               zepsherz  = zepsherf * zepshertz * zepsherqz

!              zepsherz  = zepshertz * MIN( epsher, (1. - unass) * zgrasratz / znrat3, (1. - unass) * zgrasratn )
              zgrazzn   = zgraztotc * MAX( 0. , ( 1. - unass ) * zgrasratz - znrat3 * zepsherz )
              ENDIF
              IF (ln_cobalt) THEN
              zgrasratc  = ( zgraztotfc + rtrn ) / ( zgraztotc + rtrn )
              zepshertc  = MIN( 1., zgrasratn, zgrasratc / ( corat3 * 1000. ) )
               zepsherqc  = 0.5 + (1.0 - 0.5) * zepshertc * ( 1.0 + 1.0 ) / ( zepshertc + 1.0 )
               zepsherc  = zepsherf * zepshertc * zepsherqc

!              zepsherc  = zepshertc * MIN( epsher, (1. - unass) * zgrasratc / ( corat3 * 1000. ) , (1. - unass) * zgrasratn )
              zgrazco   = zgraztotc * MAX( 0. , ( 1. - unass ) * zgrasratc - ( corat3 * 1000. ) * zepsherc )
              ENDIF
              IF (ln_manganese) THEN
              zgrasratm  = ( zgraztotfm + rtrn ) / ( zgraztotc + rtrn )
              zepshertm  = MIN( 1., zgrasratn, zgrasratm / ( mnrat3 ) )
               zepsherqm  = 0.5 + (1.0 - 0.5) * zepshertm * ( 1.0 + 1.0 ) / ( zepshertm + 1.0 )
               zepsherm  = zepsherf * zepshertm * zepsherqm

!              zepsherm  = zepshertm * MIN( epsher, (1. - unass) * zgrasratm / ( mnrat3 ) , (1. - unass) * zgrasratn )
              zgrazmn   = zgraztotc * MAX( 0. , ( 1. - unass ) * zgrasratm - ( mnrat3 ) * zepsherm )
              ENDIF

               !  Update of the TRA arrays
               !  ------------------------
               zgrarsig  = zgrarem * sigma1
               tra(ji,jj,jk,jppo4) = tra(ji,jj,jk,jppo4) + zgrarsig
               tra(ji,jj,jk,jpnh4) = tra(ji,jj,jk,jpnh4) + zgrarsig
               tra(ji,jj,jk,jpdoc) = tra(ji,jj,jk,jpdoc) + zgrarem - zgrarsig
               !
               IF( ln_ligand ) THEN
                  tra(ji,jj,jk,jplgw) = tra(ji,jj,jk,jplgw) + (zgrarem - zgrarsig) * ldocz
                  zzligprod(ji,jj,jk) = (zgrarem - zgrarsig) * ldocz
               ENDIF
               !
              IF (ln_copper) THEN
               tra(ji,jj,jk,jpdcu) = tra(ji,jj,jk,jpdcu) + zgrazcu
               zcuzoo(ji,jj,jk) = zgrazcu
               tra(ji,jj,jk,jpcup) = tra(ji,jj,jk,jpcup) + zgraztotfcu * unass
               ENDIF
              IF (ln_cobalt) THEN
               tra(ji,jj,jk,jpdco) = tra(ji,jj,jk,jpdco) + zgrazco
               zcozoo(ji,jj,jk) = zgrazco
               tra(ji,jj,jk,jpcop) = tra(ji,jj,jk,jpcop) + zgraztotfc * unass
               ENDIF
              IF (ln_manganese) THEN
               tra(ji,jj,jk,jpdmn) = tra(ji,jj,jk,jpdmn) + zgrazmn
               zmnzoo(ji,jj,jk) = zgrazmn
               tra(ji,jj,jk,jpmnp) = tra(ji,jj,jk,jpmnp) + zgraztotfm * unass
               ENDIF

              IF (ln_zinc) THEN
               tra(ji,jj,jk,jpdzn) = tra(ji,jj,jk,jpdzn) + zgrazzn
               zznzoo(ji,jj,jk) = zgrazzn
               tra(ji,jj,jk,jpznp) = tra(ji,jj,jk,jpznp) + zgraztotfz * unass
               ENDIF

               tra(ji,jj,jk,jpoxy) = tra(ji,jj,jk,jpoxy) - o2ut * zgrarsig
               tra(ji,jj,jk,jpfer) = tra(ji,jj,jk,jpfer) + zgrafer
               zfezoo(ji,jj,jk)    = zgrafer
               tra(ji,jj,jk,jppoc) = tra(ji,jj,jk,jppoc) + zgrapoc
               prodpoc(ji,jj,jk)   = prodpoc(ji,jj,jk) + zgrapoc
               tra(ji,jj,jk,jpsfe) = tra(ji,jj,jk,jpsfe) + zgraztotf * unass
               tra(ji,jj,jk,jpdic) = tra(ji,jj,jk,jpdic) + zgrarsig
               tra(ji,jj,jk,jptal) = tra(ji,jj,jk,jptal) + rno3 * zgrarsig
               !   Update the arrays TRA which contain the biological sources and sinks
               !   --------------------------------------------------------------------
               zmortz = ztortz + zrespz
               tra(ji,jj,jk,jpzoo) = tra(ji,jj,jk,jpzoo) - zmortz + zepsherv * zgraztotc 
               tra(ji,jj,jk,jpphy) = tra(ji,jj,jk,jpphy) - zgrazp
               tra(ji,jj,jk,jpdia) = tra(ji,jj,jk,jpdia) - zgrazsd
               tra(ji,jj,jk,jpnch) = tra(ji,jj,jk,jpnch) - zgrazp  * trb(ji,jj,jk,jpnch)/(trb(ji,jj,jk,jpphy)+rtrn)
               tra(ji,jj,jk,jpdch) = tra(ji,jj,jk,jpdch) - zgrazsd * trb(ji,jj,jk,jpdch)/(trb(ji,jj,jk,jpdia)+rtrn)
               tra(ji,jj,jk,jpdsi) = tra(ji,jj,jk,jpdsi) - zgrazsd * trb(ji,jj,jk,jpdsi)/(trb(ji,jj,jk,jpdia)+rtrn)
               tra(ji,jj,jk,jpgsi) = tra(ji,jj,jk,jpgsi) + zgrazsd * trb(ji,jj,jk,jpdsi)/(trb(ji,jj,jk,jpdia)+rtrn)
               tra(ji,jj,jk,jpnfe) = tra(ji,jj,jk,jpnfe) - zgrazpf
               tra(ji,jj,jk,jpdfe) = tra(ji,jj,jk,jpdfe) - zgrazsf
               tra(ji,jj,jk,jppoc) = tra(ji,jj,jk,jppoc) + zmortz - zgrazm
               prodpoc(ji,jj,jk) = prodpoc(ji,jj,jk) + zmortz
               conspoc(ji,jj,jk) = conspoc(ji,jj,jk) - zgrazm
               tra(ji,jj,jk,jpsfe) = tra(ji,jj,jk,jpsfe) + ferat3 * zmortz - zgrazmf
              IF (ln_copper) THEN
               tra(ji,jj,jk,jpcun) = tra(ji,jj,jk,jpcun) - zgrazpfcu
               tra(ji,jj,jk,jpcud) = tra(ji,jj,jk,jpcud) - zgrazsfcu
               tra(ji,jj,jk,jpcup) = tra(ji,jj,jk,jpcup) + (curat3 ) * zmortz -zgrazmfcu
               ENDIF
              IF (ln_zinc) THEN
               tra(ji,jj,jk,jpznn) = tra(ji,jj,jk,jpznn) - zgrazpfz
               tra(ji,jj,jk,jpznd) = tra(ji,jj,jk,jpznd) - zgrazsfz
               tra(ji,jj,jk,jpznf) = tra(ji,jj,jk,jpznf) + zgrazsfz * trb(ji,jj,jk,jpzfd)/(trb(ji,jj,jk,jpznd)+rtrn)
               tra(ji,jj,jk,jpzfd) = tra(ji,jj,jk,jpzfd) - zgrazpfz * trb(ji,jj,jk,jpzfd)/(trb(ji,jj,jk,jpznd)+rtrn)
               tra(ji,jj,jk,jpznp) = tra(ji,jj,jk,jpznp) + znrat3 * zmortz - zgrazmfz
               ENDIF
              IF (ln_cobalt) THEN
               tra(ji,jj,jk,jpcon) = tra(ji,jj,jk,jpcon) - zgrazpfc
               tra(ji,jj,jk,jpcod) = tra(ji,jj,jk,jpcod) - zgrazsfc
               tra(ji,jj,jk,jpcop) = tra(ji,jj,jk,jpcop) + (corat3 * 1000. ) * zmortz -zgrazmfc
               ENDIF
               !
              IF (ln_manganese) THEN
               tra(ji,jj,jk,jpmnn) = tra(ji,jj,jk,jpmnn) - zgrazpfm
               tra(ji,jj,jk,jpmnd) = tra(ji,jj,jk,jpmnd) - zgrazsfm
               tra(ji,jj,jk,jpmnp) = tra(ji,jj,jk,jpmnp) + (mnrat3 ) * zmortz -zgrazmfm
               ENDIF
 
               ! calcite production
               zprcaca = xfracal(ji,jj,jk) * zgrazp
               prodcal(ji,jj,jk) = prodcal(ji,jj,jk) + zprcaca  ! prodcal=prodcal(nanophy)+prodcal(microzoo)+prodcal(mesozoo)
               !
               zprcaca = part * zprcaca
               tra(ji,jj,jk,jpdic) = tra(ji,jj,jk,jpdic) - zprcaca
               tra(ji,jj,jk,jptal) = tra(ji,jj,jk,jptal) - 2. * zprcaca
               tra(ji,jj,jk,jpcal) = tra(ji,jj,jk,jpcal) + zprcaca
            END DO
         END DO
      END DO
      !
      IF( lk_iomput ) THEN
         IF( knt == nrdttrc ) THEN
           ALLOCATE( zw3d(jpi,jpj,jpk) )
           IF( iom_use( "GRAZ1" ) ) THEN
              zw3d(:,:,:) = zgrazing(:,:,:) * 1.e+3 * rfact2r * tmask(:,:,:)  !  Total grazing of phyto by zooplankton
              CALL iom_put( "GRAZ1", zw3d )
           ENDIF
           IF( iom_use( "FEZOO" ) ) THEN
              zw3d(:,:,:) = zfezoo(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)   !
              CALL iom_put( "FEZOO", zw3d )
           ENDIF
           IF( iom_use( "LPRODZ" ) .AND. ln_ligand )  THEN
              zw3d(:,:,:) = zzligprod(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)
              CALL iom_put( "LPRODZ"  , zw3d )
           ENDIF
IF (ln_copper) THEN 
         IF( iom_use( "CUZOO" ) ) THEN
            zw3d(:,:,:) = zcuzoo(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)
            CALL iom_put( "CUZOO", zw3d )
         ENDIF
ENDIF
IF (ln_zinc) THEN
         IF( iom_use( "ZNZOO" ) ) THEN
            zw3d(:,:,:) = zznzoo(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)
            CALL iom_put( "ZNZOO", zw3d )
         ENDIF
ENDIF
IF (ln_cobalt) THEN
         IF( iom_use( "COZOO" ) ) THEN
            zw3d(:,:,:) = zcozoo(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)!
            CALL iom_put( "COZOO", zw3d )
         ENDIF
ENDIF
IF (ln_manganese) THEN
         IF( iom_use( "MNZOO" ) ) THEN
            zw3d(:,:,:) = zmnzoo(:,:,:) * 1e9 * 1.e+3 * rfact2r * tmask(:,:,:)!
            CALL iom_put( "MNZOO", zw3d )
         ENDIF
ENDIF

           DEALLOCATE( zw3d )
         ENDIF
      ENDIF
      !
      IF (ln_ligand)  DEALLOCATE( zzligprod )
      IF (ln_copper) DEALLOCATE( zcuzoo )
      IF (ln_zinc) DEALLOCATE( zznzoo )
      IF (ln_cobalt) DEALLOCATE( zcozoo )
      IF (ln_manganese) DEALLOCATE( zmnzoo )
      !
      IF(ln_ctl) THEN      ! print mean trends (used for debugging)
         WRITE(charout, FMT="('micro')")
         CALL prt_ctl_trc_info(charout)
         CALL prt_ctl_trc(tab4d=tra, mask=tmask, clinfo=ctrcnm)
      ENDIF
      !
      IF( ln_timing )   CALL timing_stop('p4z_micro')
      !
   END SUBROUTINE p4z_micro


   SUBROUTINE p4z_micro_init
      !!----------------------------------------------------------------------
      !!                  ***  ROUTINE p4z_micro_init  ***
      !!
      !! ** Purpose :   Initialization of microzooplankton parameters
      !!
      !! ** Method  :   Read the nampiszoo namelist and check the parameters
      !!                called at the first timestep (nittrc000)
      !!
      !! ** input   :   Namelist nampiszoo
      !!
      !!----------------------------------------------------------------------
      INTEGER ::   ios   ! Local integer
      !
      NAMELIST/namp4zzoo/ part, grazrat, resrat, mzrat, xprefn, xprefc, &
         &                xprefd,  xthreshdia,  xthreshphy,  xthreshpoc, &
         &                xthresh, xkgraz, epsher, epshermin, sigma1, unass
      !!----------------------------------------------------------------------
      !
      IF(lwp) THEN
         WRITE(numout,*) 
         WRITE(numout,*) 'p4z_micro_init : Initialization of microzooplankton parameters'
         WRITE(numout,*) '~~~~~~~~~~~~~~'
      ENDIF
      !
      REWIND( numnatp_ref )              ! Namelist nampiszoo in reference namelist : Pisces microzooplankton
      READ  ( numnatp_ref, namp4zzoo, IOSTAT = ios, ERR = 901)
901   IF( ios /= 0 )   CALL ctl_nam ( ios , 'namp4zzoo in reference namelist', lwp )
      REWIND( numnatp_cfg )              ! Namelist nampiszoo in configuration namelist : Pisces microzooplankton
      READ  ( numnatp_cfg, namp4zzoo, IOSTAT = ios, ERR = 902 )
902   IF( ios >  0 )   CALL ctl_nam ( ios , 'namp4zzoo in configuration namelist', lwp )
      IF(lwm) WRITE( numonp, namp4zzoo )
      !
      IF(lwp) THEN                         ! control print
         WRITE(numout,*) '   Namelist : namp4zzoo'
         WRITE(numout,*) '      part of calcite not dissolved in microzoo guts  part        =', part
         WRITE(numout,*) '      microzoo preference for POC                     xprefc      =', xprefc
         WRITE(numout,*) '      microzoo preference for nano                    xprefn      =', xprefn
         WRITE(numout,*) '      microzoo preference for diatoms                 xprefd      =', xprefd
         WRITE(numout,*) '      diatoms feeding threshold  for microzoo         xthreshdia  =', xthreshdia
         WRITE(numout,*) '      nanophyto feeding threshold for microzoo        xthreshphy  =', xthreshphy
         WRITE(numout,*) '      poc feeding threshold for microzoo              xthreshpoc  =', xthreshpoc
         WRITE(numout,*) '      feeding threshold for microzooplankton          xthresh     =', xthresh
         WRITE(numout,*) '      exsudation rate of microzooplankton             resrat      =', resrat
         WRITE(numout,*) '      microzooplankton mortality rate                 mzrat       =', mzrat
         WRITE(numout,*) '      maximal microzoo grazing rate                   grazrat     =', grazrat
         WRITE(numout,*) '      non assimilated fraction of P by microzoo       unass       =', unass
         WRITE(numout,*) '      Efficicency of microzoo growth                  epsher      =', epsher
         WRITE(numout,*) '      Minimum efficicency of microzoo growth          epshermin   =', epshermin
         WRITE(numout,*) '      Fraction of microzoo excretion as DOM           sigma1      =', sigma1
         WRITE(numout,*) '      half sturation constant for grazing 1           xkgraz      =', xkgraz
      ENDIF
      !
   END SUBROUTINE p4z_micro_init

   !!======================================================================
END MODULE p4zmicro
