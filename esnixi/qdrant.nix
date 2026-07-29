{ ... }:
{
  # Run Qdrant as a Docker container to avoid Rust 1.97 AVX-512 VNNI build failure
  virtualisation.oci-containers.containers.qdrant = {
    image = "qdrant/qdrant:v1.18.2";
    ports = [ "6333:6333" "6334:6334" ];
    volumes = [ "qdrant_data:/qdrant/storage" ];
  };
}
