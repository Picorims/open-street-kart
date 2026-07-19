# Terrain3D Textures

Terrain3D textures are made with MaterialMaker and channel packed with GIMP. The process is the following:
1. Make the material in MM;
2. Export to Godot 4 StandardMaterial3D into `materials/environment/terrain`;
3. Use GIMP to channel pack into albedo/height and normal/Ambiant Occlusion/roughness textures (see: https://youtu.be/oV8c9alXVwU?t=273 and https://terrain3d.readthedocs.io/en/stable/docs/texture_prep.html)
4. Setup textures using Terrain3D Godot Add-on GUI, when creating a new asset pack.

Note: Asset packs (resource) should be stored in a separate file to not bloat scenes. 