{ flake }:

{
  # Typed registry for AI-owned flake inputs.
  #
  # Nix flakes require top-level inputs to be declared statically in flake.nix,
  # so this file does not declare inputs. It gives catalog and feature modules a
  # single purpose-oriented place to resolve pinned skill, MCP, and tool sources.
  skills = {
    caveman = flake.inputs.caveman;
    gstack = flake.inputs.gstack;
    mattpocock-skills = flake.inputs.mattpocock-skills;
  };

  mcps = {
    codebase-memory = flake.inputs.codebase-memory-mcp;
    serena = flake.inputs.serena;
  };
}
