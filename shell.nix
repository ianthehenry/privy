{ nixpkgs ? import <nixpkgs> {} }:
with nixpkgs; mkShellNoCC {
  nativeBuildInputs = [janet python39Packages.cram];
}
