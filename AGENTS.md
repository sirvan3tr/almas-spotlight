- Small files in structured packaging
- Structure yourself around Makefile
- Maintain a /docs/ folder with markdown and links.
- Apply a Fail-Fast approach.

- always take a data and security first approach.
- use concrete data structures that allows functions to fail fast and avoiding silent errors.

### **Core Design Principles**

- **Decompose before you compose**: Break problems down into nearly atomic parts before attempting to build a solution.

- **Design as a plan**: Treat design as a written plan for form and structure, separate from the execution.
- **Iterate on design, not just implementation**: It is easier to iterate on a plan than on a finished implementation.
- **Embrace constraints**: Use constraints to drive creativity and make firm decisions rather than leaving everything configurable.
- **Design "instruments," not "choose-a-phones"**: Build tools that are minimal, focused on one "excitation," and sufficient for their task.
- **Prioritize the machine interface**: Always design a machine-readable interface (like data-driven APIs) before a human-readable one (like strings or SQL).
- **Convey decisions**: The value of design is in making decisions and conveying them to the next person, not in keeping all options open.

### **Architecture and State**

- **Separate Information from Mechanism**: Distinguish between the data your system manages and the programming constructs used to manipulate it.

- **Acknowledge that complexity is caused by State**: Avoid place-oriented programming (update-in-place) as it destroys the basis for logic.
- **Default to Immutability**: Treat the database and application state as an immutable, expanding value.
- **Use Accretion over Update**: Never overwrite data; only add new facts. The past should not change.
- **Reify Process**: Turn transitions and novelty into data (assertions and retractions) that can be stored, moved, and queried.
- **Separate Reads and Writes**: Decouple the coordination of novelty (writes) from the processing of history and queries (reads).
- **Empower Peers**: Move query engines and business logic to the application layer ("peers") rather than trapping them in a privileged server.
- **Use Declarative Programming**: Use set-oriented, declarative logic (like Datalog) to describe *what* you want rather than *how* to get it.
- **Model facts with EAVT**: Represent information as atomic facts consisting of Entity, Attribute, Value, and Time.

### **Data Structure and Specs**

- **Apply "Open World" semantics**: Never disallow extra keys in maps; ignore what you don't understand to allow for future growth.

- **Code for Growth, not Change**: Categorize updates as "Growth" (providing more or requiring less) or "Breakage" (providing less or requiring more).
- **Never make breaking changes**: If a function’s requirements or provisions must change incompatibly, create a new function (e.g., `foo2`) instead of trashing the original.
- **Ensure Enduring Names**: Once a name (function, namespace, or artifact) is published, its semantics must remain stable forever.
- **Recognize Collections**: Treat namespaces as collections of vars and artifacts as collections of namespaces; only add to them to ensure growth.
- **Avoid "Semantic Versioning" as an excuse for breakage**: Major version bumps are a recipe for breaking software; prefer accretion and renaming.
- **Seek Harmony**: Prioritize how parts fit together (simultaneity) over just sequential execution.
- **Avoid Level Violations**: Do not let changes in a leaf function trigger a cascade of version bumps across unrelated artifacts.
- **Assume an Unknown Context**: Code should be designed to run in environments and with dependencies that the author cannot fully foresee or test.
- **Use concrete, sorted sets of facts**: Provide leverage over data by organizing it into indexed, sorted representations.

### **Developer Discipline**

- **Practice "Shedding"**: Dedicate significant time to practicing, studying, and thinking (the "hammock") rather than just performing (coding).

- **Don't cater only to beginners**: Do not eliminate all effort or complexity if it compromises the power and simplicity of the "instrument" for experts.
- **Be a Luthier, not just a Player**: Understand the design stack below you, but don't let "soldering" distract you from making "music" (solving the domain problem).
- **Value Exchange over Change**: When writing libraries, focus on the social contract of providing stable, reliable code to others.
