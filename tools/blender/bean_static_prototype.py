"""Build or export Bean Party's canonical static prototype character.

Run through tools/assets.ps1 or tools/assets.sh so Blender version checks and
repository-relative paths stay consistent across contributor machines.
"""

from __future__ import annotations

import argparse
import math
import sys
import traceback
from pathlib import Path

import bpy


ASSET_COLLECTION = "BP_BeanStaticPrototype"
EXPORT_ORIENTATION_NAME = "GodotForward"
BODY_RADIUS = 0.32
BODY_BOTTOM = 0.36
BODY_CYLINDER_BOTTOM = 0.68
BODY_CYLINDER_TOP = 1.43
BODY_TOP = 1.75
REST_CURVE_DEPTH = 0.07875
RADIAL_SEGMENTS = 24


def parse_args() -> argparse.Namespace:
    args = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument("--mode", choices=("build", "export"), required=True)
    parser.add_argument("--source", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    return parser.parse_args(args)


def make_material(
    name: str,
    color: tuple[float, float, float, float],
    roughness: float,
) -> bpy.types.Material:
    material = bpy.data.materials.new(name)
    material.diffuse_color = color
    material.use_nodes = True
    principled = material.node_tree.nodes.get("Principled BSDF")
    principled.inputs["Base Color"].default_value = color
    metallic = principled.inputs.get("Metallic IOR Level")
    if metallic is None:
        metallic = principled.inputs.get("Metallic")
    if metallic is not None:
        metallic.default_value = 0.0
    principled.inputs["Roughness"].default_value = roughness
    return material


def move_to_collection(obj: bpy.types.Object, collection: bpy.types.Collection) -> None:
    for current_collection in list(obj.users_collection):
        current_collection.objects.unlink(obj)
    collection.objects.link(obj)


def add_ellipsoid(
    name: str,
    location: tuple[float, float, float],
    scale: tuple[float, float, float],
    material: bpy.types.Material,
    collection: bpy.types.Collection,
    rotation: tuple[float, float, float] = (0.0, 0.0, 0.0),
    segments: int = 20,
    rings: int = 12,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_uv_sphere_add(
        segments=segments,
        ring_count=rings,
        location=location,
        rotation=rotation,
    )
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    for polygon in obj.data.polygons:
        polygon.use_smooth = True
    obj.data.materials.append(material)
    move_to_collection(obj, collection)
    return obj


def rest_curve_offset(z: float) -> float:
    t = (z - BODY_BOTTOM) / (BODY_TOP - BODY_BOTTOM)
    return REST_CURVE_DEPTH * 16.0 * t * t * (1.0 - t) * (1.0 - t)


def rest_curve_slope(z: float) -> float:
    t = (z - BODY_BOTTOM) / (BODY_TOP - BODY_BOTTOM)
    return (
        REST_CURVE_DEPTH
        * 32.0
        * t
        * (1.0 - t)
        * (1.0 - 2.0 * t)
        / (BODY_TOP - BODY_BOTTOM)
    )


def add_bent_capsule(
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    ring_specs: list[tuple[float, float]] = []
    for step in range(1, 9):
        angle = math.pi * step / 16.0
        ring_specs.append(
            (
                BODY_CYLINDER_BOTTOM - BODY_RADIUS * math.cos(angle),
                BODY_RADIUS * math.sin(angle),
            )
        )
    for step in range(1, 5):
        ring_specs.append(
            (
                BODY_CYLINDER_BOTTOM
                + (BODY_CYLINDER_TOP - BODY_CYLINDER_BOTTOM) * step / 4.0,
                BODY_RADIUS,
            )
        )
    for step in range(1, 8):
        angle = math.pi * step / 16.0
        ring_specs.append(
            (
                BODY_CYLINDER_TOP + BODY_RADIUS * math.sin(angle),
                BODY_RADIUS * math.cos(angle),
            )
        )

    vertices: list[tuple[float, float, float]] = [(0.0, 0.0, BODY_BOTTOM)]
    for z, ring_radius in ring_specs:
        center_y = rest_curve_offset(z)
        slope = rest_curve_slope(z)
        normal_length = math.sqrt(1.0 + slope * slope)
        normal_y = 1.0 / normal_length
        normal_z = -slope / normal_length
        for segment in range(RADIAL_SEGMENTS):
            angle = math.tau * segment / RADIAL_SEGMENTS
            radial_x = ring_radius * math.cos(angle)
            radial_yz = ring_radius * math.sin(angle)
            vertices.append(
                (
                    radial_x,
                    center_y + normal_y * radial_yz,
                    z + normal_z * radial_yz,
                )
            )
    vertices.append((0.0, 0.0, BODY_TOP))

    faces: list[tuple[int, ...]] = []
    first_ring = 1
    for segment in range(RADIAL_SEGMENTS):
        following = (segment + 1) % RADIAL_SEGMENTS
        faces.append((0, first_ring + following, first_ring + segment))
    for ring_index in range(len(ring_specs) - 1):
        current = first_ring + ring_index * RADIAL_SEGMENTS
        following_ring = current + RADIAL_SEGMENTS
        for segment in range(RADIAL_SEGMENTS):
            following = (segment + 1) % RADIAL_SEGMENTS
            faces.append(
                (
                    current + segment,
                    current + following,
                    following_ring + following,
                    following_ring + segment,
                )
            )
    top_pole = len(vertices) - 1
    last_ring = first_ring + (len(ring_specs) - 1) * RADIAL_SEGMENTS
    for segment in range(RADIAL_SEGMENTS):
        following = (segment + 1) % RADIAL_SEGMENTS
        faces.append((top_pole, last_ring + segment, last_ring + following))

    mesh = bpy.data.meshes.new("BeanBodyMesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    for polygon in mesh.polygons:
        polygon.use_smooth = True
    body = bpy.data.objects.new("Body", mesh)
    collection.objects.link(body)
    body.data.materials.append(material)
    return body


def add_shoe(
    name: str,
    x: float,
    rotation_z: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    vertices = [
        (-0.0798, 0.1232, 0.0550),
        (0.0798, 0.1232, 0.0550),
        (-0.1102, -0.3360, 0.0550),
        (0.1102, -0.3360, 0.0550),
        (-0.0798, 0.1232, 0.1652),
        (0.0798, 0.1232, 0.1652),
        (-0.1102, -0.3360, 0.1158),
        (0.1102, -0.3360, 0.1158),
    ]
    faces = [
        (0, 1, 3, 2),
        (4, 6, 7, 5),
        (0, 4, 5, 1),
        (2, 3, 7, 6),
        (0, 2, 6, 4),
        (1, 5, 7, 3),
    ]
    mesh = bpy.data.meshes.new(f"{name}Mesh")
    mesh.from_pydata(vertices, [], faces)
    mesh.validate()
    mesh.update()
    shoe = bpy.data.objects.new(name, mesh)
    shoe.location = (x, 0.0, 0.0)
    shoe.rotation_euler.z = rotation_z
    shoe.data.materials.append(material)
    collection.objects.link(shoe)
    bevel = shoe.modifiers.new("Soft shoe edges", type="BEVEL")
    bevel.width = 0.018
    bevel.segments = 2
    bpy.context.view_layer.objects.active = shoe
    shoe.select_set(True)
    bpy.ops.object.modifier_apply(modifier=bevel.name)
    shoe.select_set(False)
    for polygon in shoe.data.polygons:
        polygon.use_smooth = True
    return shoe


def add_shin(
    name: str,
    x: float,
    material: bpy.types.Material,
    collection: bpy.types.Collection,
) -> bpy.types.Object:
    bpy.ops.mesh.primitive_cylinder_add(
        vertices=12,
        radius=0.0525,
        depth=0.24,
        location=(x, 0.0, 0.25),
    )
    shin = bpy.context.object
    shin.name = name
    shin.data.materials.append(material)
    move_to_collection(shin, collection)
    for polygon in shin.data.polygons:
        polygon.use_smooth = True
    return shin


def build_scene(source_path: Path) -> None:
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for collection in list(bpy.data.collections):
        bpy.data.collections.remove(collection)

    scene_collection = bpy.context.scene.collection
    asset_collection = bpy.data.collections.new(ASSET_COLLECTION)
    scene_collection.children.link(asset_collection)

    primary = make_material(
        "identity_primary",
        (0.337255, 0.705882, 0.913725, 1.0),
        0.48,
    )
    eye_white = make_material("eye_white", (0.98, 0.98, 0.96, 1.0), 0.36)
    pupil = make_material("pupil_dark", (0.086, 0.086, 0.086, 1.0), 0.55)
    shoe = make_material("shoe_primary", (0.42, 0.24, 0.18, 1.0), 0.68)

    body = add_bent_capsule(primary, asset_collection)
    body["asset_id"] = "bean-static-prototype"
    body["asset_status"] = "canonical-prototype"
    body["units"] = "meters"
    body["godot_forward"] = "-Z"
    add_shoe("Shoe_Left", -0.145, -math.radians(6.0), shoe, asset_collection)
    add_shoe("Shoe_Right", 0.145, math.radians(6.0), shoe, asset_collection)
    add_shin("Shin_Left", -0.145, shoe, asset_collection)
    add_shin("Shin_Right", 0.145, shoe, asset_collection)

    eye_rotation = (0.142928, 0.0, 0.0)
    add_ellipsoid(
        "Eye_Left_White",
        (-0.070, -0.250091, 1.265523),
        (0.045, 0.022, 0.039),
        eye_white,
        asset_collection,
        rotation=eye_rotation,
        segments=20,
        rings=12,
    )
    add_ellipsoid(
        "Eye_Right_White",
        (0.070, -0.250091, 1.265523),
        (0.045, 0.022, 0.039),
        eye_white,
        asset_collection,
        rotation=eye_rotation,
        segments=20,
        rings=12,
    )
    add_ellipsoid(
        "Pupil_Left",
        (-0.070, -0.273847, 1.262104),
        (0.014, 0.008, 0.014),
        pupil,
        asset_collection,
        rotation=eye_rotation,
        segments=16,
        rings=8,
    )
    add_ellipsoid(
        "Pupil_Right",
        (0.070, -0.273847, 1.262104),
        (0.014, 0.008, 0.014),
        pupil,
        asset_collection,
        rotation=eye_rotation,
        segments=16,
        rings=8,
    )

    export_orientation = bpy.data.objects.new(EXPORT_ORIENTATION_NAME, None)
    export_orientation.rotation_euler.z = math.pi
    asset_collection.objects.link(export_orientation)
    for obj in list(asset_collection.objects):
        if obj != export_orientation:
            obj.parent = export_orientation

    bpy.context.scene["asset_id"] = "bean-static-prototype"
    bpy.context.scene["asset_status"] = "canonical-prototype"
    bpy.context.scene["authoring_version"] = "Blender 5.1.2"
    bpy.context.scene["target_height_m"] = 1.75
    bpy.context.scene["triangle_budget"] = 6000

    source_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(source_path.resolve()))


def export_glb(output_path: Path) -> None:
    collection = bpy.data.collections.get(ASSET_COLLECTION)
    if collection is None:
        raise RuntimeError(f"Missing collection {ASSET_COLLECTION!r}")

    bpy.ops.object.select_all(action="DESELECT")
    for obj in collection.all_objects:
        if obj.type in {"EMPTY", "MESH"}:
            obj.select_set(True)

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.export_scene.gltf(
        filepath=str(output_path.resolve()),
        export_format="GLB",
        use_selection=True,
        export_apply=True,
        export_materials="EXPORT",
        export_cameras=False,
        export_lights=False,
        export_animations=False,
        export_extras=True,
        export_yup=True,
    )


def main() -> None:
    args = parse_args()
    if args.mode == "build":
        if args.source is None:
            raise ValueError("--source is required for build mode")
        build_scene(args.source)
    export_glb(args.output)


if __name__ == "__main__":
    try:
        main()
    except Exception:
        traceback.print_exc()
        sys.exit(1)
