!< Define the abstract conservative compressible state of a Riemann Problem for FORESEER library.

module foreseer_conservative_compressible
!< Define the abstract conservative compressible state of a Riemann Problem for FORESEER library.

use, intrinsic :: iso_fortran_env, only : stderr=>error_unit
use foreseer_conservative_object, only : conservative_object
use foreseer_eos_object, only : eos_object
use penf, only : R8P, str
use vecfor, only : vector

implicit none
private
public :: conservative_compressible
public :: conservative_compressible_pointer

type, extends(conservative_object) :: conservative_compressible
   !< Convervative compressible object class.
   real(R8P)    :: density=0._R8P !< Density, `rho`.
   type(vector) :: momentum       !< Momentum, `rho * v`, `rho` being the density and `v` the velocity vector.
   real(R8P)    :: energy=0._R8P  !< Energy, `rho * E`, `rho` being the density and `E` the specific energy.
   contains
      ! public methods
      procedure, pass(self) :: compute_fluxes_from_primitive !< Compute conservative fluxes from primitives at interface.
      ! deferred methods
      procedure, pass(self) :: array              !< Return serialized array of conservative.
      procedure, pass(self) :: compute_fluxes     !< Compute conservative fluxes.
      procedure, pass(self) :: description        !< Return pretty-printed object description.
      procedure, pass(self) :: destroy            !< Destroy conservative.
      procedure, pass(self) :: initialize         !< Initialize conservative.
      procedure, pass(self) :: pressure           !< Return pressure value.
      procedure, pass(self) :: velocity           !< Return velocity vector.
      procedure, pass(lhs)  :: cons_assign_cons   !< Operator `=`.
      procedure, pass(lhs)  :: cons_divide_real   !< Operator `cons / real`.
      procedure, pass(lhs)  :: cons_multiply_real !< Operator `cons * real`.
      procedure, pass(lhs)  :: cons_multiply_cons !< Operator `*`.
      procedure, pass(rhs)  :: real_multiply_cons !< Operator `real * cons`.
      procedure, pass(lhs)  :: add                !< Operator `+`.
      procedure, pass(self) :: positive           !< Unary operator `+ cons`.
      procedure, pass(lhs)  :: sub                !< Operator `-`.
      procedure, pass(self) :: negative           !< Unary operator `- cons`.
endtype conservative_compressible

interface conservative_compressible
   !< Overload [[conservative_compressible]] name with its constructor.
   module procedure conservative_compressible_instance
endinterface

contains
   ! public non TBP
   function conservative_compressible_pointer(to, error_message) result(pointer_)
   !< Return [[conservative_compressible]] pointer associated to [[conservative_object]] or its extensions until
   !< [[conservative_compressible]] included.
   !<
   !< @note A type-guard check is performed and error stop is raised if necessary.
   class(conservative_object), intent(in), target   :: to            !< Target of associate.
   character(*),               intent(in), optional :: error_message !< Auxiliary error message.
   class(conservative_compressible), pointer        :: pointer_      !< Associated pointer.

   select type(to)
   type is(conservative_compressible)
      pointer_ => to
   class default
      write(stderr, '(A)') 'error: cast conservative_object to conservative_compressible failed!'
      if (present(error_message)) write(stderr, '(A)') error_message
      stop
   endselect
   endfunction conservative_compressible_pointer

   ! public methods
   elemental subroutine compute_fluxes_from_primitive(self, eos, p, r, u, normal)
   !< Compute conservative fluxes from primitives at interface.
   class(conservative_compressible), intent(inout) :: self   !< Conservative.
   class(eos_object),                intent(in)    :: eos    !< Equation of state.
   real(R8P),                        intent(in)    :: p      !< Pressure at interface.
   real(R8P),                        intent(in)    :: r      !< Density at interface.
   real(R8P),                        intent(in)    :: u      !< Velocity (normal component) at interface.
   type(vector),                     intent(in)    :: normal !< Normal (versor) of face where fluxes are given.

   self%density = r * u
   self%momentum = (r * u * u + p) * normal
   self%energy = (r * eos%energy(density=r, pressure=p) + r * u * u * 0.5_R8P + p) * u
   endsubroutine compute_fluxes_from_primitive

   ! deferred methods
   pure function array(self) result(array_)
   !< Return serialized array of conservative.
   class(conservative_compressible), intent(in) :: self      !< Conservative.
   real(R8P), allocatable                       :: array_(:) !< Serialized array of conservative.

   allocate(array_(1:5))
   array_(1) = self%density
   array_(2) = self%momentum%x
   array_(3) = self%momentum%y
   array_(4) = self%momentum%z
   array_(5) = self%energy
   endfunction array

   subroutine compute_fluxes(self, eos, normal, fluxes)
   !< Compute conservative fluxes.
   class(conservative_compressible), intent(in)  :: self             !< Conservative.
   class(eos_object),                intent(in)  :: eos              !< Equation of state.
   type(vector),                     intent(in)  :: normal           !< Normal (versor) of face where fluxes are given.
   class(conservative_object),       intent(out) :: fluxes           !< Conservative fluxes.
   real(R8P)                                     :: pressure_        !< Pressure value.
   type(vector)                                  :: velocity_        !< Velocity vector.
   real(R8P)                                     :: velocity_normal_ !< Velocity component parallel to given normal.

   select type(fluxes)
   class is(conservative_compressible)
      pressure_ = self%pressure(eos=eos)
      velocity_ = self%velocity()
      velocity_normal_ = velocity_.dot.normal
      fluxes%density = self%momentum.dot.normal
      fluxes%momentum = self%density * velocity_ * velocity_normal_ + pressure_ * normal
      fluxes%energy = (self%energy + pressure_) * velocity_normal_
   endselect
   endsubroutine compute_fluxes

   pure function description(self, prefix) result(desc)
   !< Return a pretty-formatted object description.
   class(conservative_compressible), intent(in)           :: self             !< Conservative.
   character(*),                     intent(in), optional :: prefix           !< Prefixing string.
   character(len=:), allocatable                          :: prefix_          !< Prefixing string, local variable.
   character(len=:), allocatable                          :: desc             !< Description.
   character(len=1), parameter                            :: NL=new_line('a') !< New line character.

   prefix_ = '' ; if (present(prefix)) prefix_ = prefix
   desc = ''
   desc = desc//prefix_//'density  = '//trim(str(n=self%density))//NL
   desc = desc//prefix_//'momentum = '//trim(str(n=[self%momentum%x, self%momentum%y, self%momentum%z]))//NL
   desc = desc//prefix_//'energy   = '//trim(str(n=self%energy))
   endfunction description

   elemental subroutine destroy(self)
   !< Destroy conservative.
   class(conservative_compressible), intent(inout) :: self  !< Conservative.
   type(conservative_compressible)                 :: fresh !< Fresh instance of conservative object.

   self = fresh
   endsubroutine destroy

   subroutine initialize(self, initial_state)
   !< Initialize conservative.
   class(conservative_compressible), intent(inout)        :: self          !< Conservative.
   class(conservative_object),       intent(in), optional :: initial_state !< Initial state.

   if (present(initial_state)) then
      select type(initial_state)
      class is(conservative_compressible)
         self = initial_state
      endselect
   else
      call self%destroy
   endif
   endsubroutine initialize

   elemental function pressure(self, eos) result(pressure_)
   !< Return pressure value.
   class(conservative_compressible), intent(in) :: self      !< Conservative.
   class(eos_object),                intent(in) :: eos       !< Equation of state.
   real(R8P)                                    :: pressure_ !< Pressure value.
   type(vector)                                 :: velocity_ !< Velocity vector.

   velocity_ = self%velocity()
   pressure_ = (eos%gam() - 1._R8P) * (self%energy - 0.5_R8P * self%density * velocity_%sq_norm())
   endfunction pressure

   elemental function velocity(self) result(velocity_)
   !< Return velocity vector.
   class(conservative_compressible), intent(in) :: self      !< Conservative.
   type(vector)                                 :: velocity_ !< Velocity vector.

   velocity_ = self%momentum / self%density
   endfunction velocity

   ! operators
   pure subroutine cons_assign_cons(lhs, rhs)
   !< Operator `=`.
   class(conservative_compressible), intent(inout) :: lhs !< Left hand side.
   class(conservative_object),       intent(in)    :: rhs !< Right hand side.

   select type(rhs)
   class is (conservative_compressible)
      lhs%density  = rhs%density
      lhs%momentum = rhs%momentum
      lhs%energy   = rhs%energy
   endselect
   endsubroutine cons_assign_cons

   function cons_divide_real(lhs, rhs) result(operator_result)
   !< Operator `cons / real`.
   class(conservative_compressible), intent(in) :: lhs             !< Left hand side.
   real(R8P),                        intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result%density  = lhs%density  / rhs
      operator_result%momentum = lhs%momentum / rhs
      operator_result%energy   = lhs%energy   / rhs
   endselect
   endfunction cons_divide_real

   function cons_multiply_real(lhs, rhs) result(operator_result)
   !< Operator `cons * real`.
   class(conservative_compressible), intent(in) :: lhs             !< Left hand side.
   real(R8P),                        intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result%density  = lhs%density  * rhs
      operator_result%momentum = lhs%momentum * rhs
      operator_result%energy   = lhs%energy   * rhs
   endselect
   endfunction cons_multiply_real

   function real_multiply_cons(lhs, rhs) result(operator_result)
   !< Operator `real * cons`.
   real(R8P),                        intent(in) :: lhs             !< Left hand side.
   class(conservative_compressible), intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result%density  = lhs * rhs%density
      operator_result%momentum = lhs * rhs%momentum
      operator_result%energy   = lhs * rhs%energy
   endselect
   endfunction real_multiply_cons

   function cons_multiply_cons(lhs, rhs) result(operator_result)
   !< Operator `*`.
   class(conservative_compressible), intent(in) :: lhs             !< Left hand side.
   class(conservative_object),       intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result = lhs
      select type(rhs)
      class is (conservative_compressible)
         operator_result%density  = lhs%density  * rhs%density
         operator_result%momentum = lhs%momentum * rhs%momentum
         operator_result%energy   = lhs%energy   * rhs%energy
      endselect
   endselect
   endfunction cons_multiply_cons

   function add(lhs, rhs) result(operator_result)
   !< Operator `+`.
   class(conservative_compressible), intent(in) :: lhs             !< Left hand side.
   class(conservative_object),       intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result = lhs
      select type(rhs)
      class is (conservative_compressible)
         operator_result%density  = lhs%density  + rhs%density
         operator_result%momentum = lhs%momentum + rhs%momentum
         operator_result%energy   = lhs%energy   + rhs%energy
      endselect
   endselect
   endfunction add

   function positive(self) result(operator_result)
   !< Unary operator `+ cons`.
   class(conservative_compressible), intent(in) :: self            !< Conservative.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result%density  = + self%density
      operator_result%momentum = + self%momentum
      operator_result%energy   = + self%energy
   endselect
   endfunction positive

   function sub(lhs, rhs) result(operator_result)
   !< Operator `+`.
   class(conservative_compressible), intent(in) :: lhs             !< Left hand side.
   class(conservative_object),       intent(in) :: rhs             !< Right hand side.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result = lhs
      select type(rhs)
      class is (conservative_compressible)
         operator_result%density  = lhs%density  - rhs%density
         operator_result%momentum = lhs%momentum - rhs%momentum
         operator_result%energy   = lhs%energy   - rhs%energy
      endselect
   endselect
   endfunction sub

   function negative(self) result(operator_result)
   !< Unary operator `- cons`.
   class(conservative_compressible), intent(in) :: self            !< Conservative.
   class(conservative_object), allocatable      :: operator_result !< Operator result.

   allocate(conservative_compressible :: operator_result)
   select type(operator_result)
   class is(conservative_compressible)
      operator_result%density  = - self%density
      operator_result%momentum = - self%momentum
      operator_result%energy   = - self%energy
   endselect
   endfunction negative

   ! private non TBP
   elemental function conservative_compressible_instance(density, momentum, energy) result(instance)
   !< Return and instance of [[conservative_compressible]].
   !<
   !< @note This procedure is used for overloading [[conservative_compressible]] name.
   real(R8P),    intent(in), optional :: density  !< Density, `rho`.
   type(vector), intent(in), optional :: momentum !< Momentum, `rho * v`, `rho` being the density and `v` the velocity vector.
   real(R8P),    intent(in), optional :: energy   !< Energy, `rho * E`, `rho` being the density and `E` the specific energy.
   type(conservative_compressible)    :: instance !< Instance of [[conservative_compressible]].

   if (present(density)) instance%density = density
   if (present(momentum)) instance%momentum = momentum
   if (present(energy)) instance%energy = energy
   endfunction conservative_compressible_instance
endmodule foreseer_conservative_compressible
