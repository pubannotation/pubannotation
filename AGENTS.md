# Project-Specific Coding Rules

- Follow the Law of Demeter. Do not traverse another object's internal structure to operate on objects reached through it. Expose the required operations as methods on the object you interact with directly. Do not judge violations solely by the presence or absence of method chaining.
- Follow the Tell, Don't Ask principle. Instead of retrieving an object's state and making decisions or performing operations in the caller, implement those decisions and operations as behavior of the object that owns the state. This does not prohibit retrieving state for display or data transfer.
- Prefer positional arguments over named arguments (keyword arguments in Ruby). Use positional arguments by default when adding methods or changing method signatures. Follow existing API or framework requirements when they require keyword arguments.
- Implement methods of stateless service classes as class methods.
