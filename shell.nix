{ nixpkgs ? import <nixpkgs> {} }:
with nixpkgs; mkShellNoCC {
  buildInputs = [janet];
}
