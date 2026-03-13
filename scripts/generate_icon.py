#!/usr/bin/env python3
"""Generate the Gradle Dependency Visualizer app icon (1024x1024 PNG).

Layers (bottom to top):
1. Rounded rectangle with Gradle green gradient
2. Elephant silhouette (Gradle mascot) as subtle watermark
3. Dependency graph with pastel-colored nodes and edges
4. Magnifying glass overlay
"""

import math
import os
import subprocess
import sys

VENV_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), ".venv")


def ensure_pillow():
    """Create a venv and install Pillow if needed, then activate it."""
    if not os.path.isdir(VENV_DIR):
        print(f"Creating venv at {VENV_DIR}...")
        subprocess.check_call([sys.executable, "-m", "venv", VENV_DIR])

    if sys.platform == "win32":
        site_packages_glob = os.path.join(VENV_DIR, "Lib", "site-packages")
    else:
        # Find the python version directory inside lib/
        lib_dir = os.path.join(VENV_DIR, "lib")
        py_dirs = (
            [d for d in os.listdir(lib_dir) if d.startswith("python")]
            if os.path.isdir(lib_dir)
            else []
        )
        if not py_dirs:
            raise RuntimeError(f"No python directory found in {lib_dir}")
        site_packages_glob = os.path.join(lib_dir, py_dirs[0], "site-packages")

    # Add venv site-packages to import path
    if site_packages_glob not in sys.path:
        sys.path.insert(0, site_packages_glob)

    try:
        import PIL  # noqa: F401
    except ImportError:
        print("Installing Pillow into venv...")
        pip = os.path.join(VENV_DIR, "bin", "pip")
        req = os.path.join(
            os.path.dirname(os.path.abspath(__file__)), "requirements.txt"
        )
        subprocess.check_call([pip, "install", "-r", req])


ensure_pillow()

from PIL import Image, ImageDraw  # noqa: E402

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def lerp_color(c1: tuple, c2: tuple, t: float) -> tuple:
    """Linearly interpolate between two RGBA colors."""
    return tuple(int(a + (b - a) * t) for a, b in zip(c1, c2))


def draw_gradient(
    draw: ImageDraw.Draw, size: int, top: tuple, bottom: tuple, radius: int
):
    """Draw a rounded-rectangle background with a vertical gradient."""
    # Build gradient line by line, then mask with rounded rect
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    gd = ImageDraw.Draw(img)
    for y in range(size):
        t = y / (size - 1)
        color = lerp_color(top, bottom, t)
        gd.line([(0, y), (size - 1, y)], fill=color)
    # Create rounded-rect mask
    mask = Image.new("L", (size, size), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return img, mask


def draw_elephant(draw: ImageDraw.Draw, size: int):
    """Draw a simplified elephant silhouette as a subtle watermark."""
    cx, cy = size * 0.50, size * 0.48
    color = (255, 255, 255, 40)  # white overlay

    # Body (large oval)
    bw, bh = size * 0.28, size * 0.20
    draw.ellipse([cx - bw, cy - bh, cx + bw, cy + bh], fill=color)

    # Head (smaller circle, front-right of body)
    hx, hy = cx + size * 0.22, cy - size * 0.08
    hr = size * 0.12
    draw.ellipse([hx - hr, hy - hr, hx + hr, hy + hr], fill=color)

    # Ear (arc behind head)
    ex, ey = hx - size * 0.04, hy - size * 0.06
    er = size * 0.14
    draw.ellipse([ex - er, ey - er, ex + er, ey + er], fill=color)

    # Trunk (curved downward from head)
    trunk_pts = [
        (hx + size * 0.08, hy + size * 0.02),
        (hx + size * 0.14, hy + size * 0.10),
        (hx + size * 0.12, hy + size * 0.22),
        (hx + size * 0.08, hy + size * 0.28),
    ]
    draw.line(trunk_pts, fill=color, width=int(size * 0.04), joint="curve")

    # Legs (four rectangles)
    leg_w = size * 0.045
    leg_h = size * 0.16
    leg_y_top = cy + bh - size * 0.04
    for lx in [cx - bw * 0.6, cx - bw * 0.2, cx + bw * 0.2, cx + bw * 0.6]:
        draw.rectangle(
            [lx - leg_w, leg_y_top, lx + leg_w, leg_y_top + leg_h], fill=color
        )

    # Tail (small line from back)
    draw.line(
        [(cx - bw, cy), (cx - bw - size * 0.06, cy - size * 0.08)],
        fill=color,
        width=int(size * 0.02),
    )


def draw_graph(draw: ImageDraw.Draw, size: int):
    """Draw a dependency tree with pastel nodes and edges."""
    # Node definitions: (x_frac, y_frac, color, radius_frac)
    pastel_colors = [
        (0.50, 0.22, "#FFB3BA", 0.040),  # root - pink
        (0.32, 0.40, "#BAE1FF", 0.035),  # child 1 - blue
        (0.68, 0.40, "#BAFFC9", 0.035),  # child 2 - green
        (0.22, 0.58, "#FFFFBA", 0.030),  # grandchild 1 - yellow
        (0.42, 0.58, "#E8BAFF", 0.030),  # grandchild 2 - purple
        (0.58, 0.58, "#FF6B6B", 0.032),  # conflict node - red
        (0.78, 0.58, "#FFD4BA", 0.030),  # grandchild 4 - orange
    ]

    # Edges: (from_idx, to_idx)
    edges = [(0, 1), (0, 2), (1, 3), (1, 4), (2, 5), (2, 6)]

    # Draw edges first
    edge_color = (255, 255, 255, 160)
    edge_width = int(size * 0.006)
    for fi, ti in edges:
        x1 = pastel_colors[fi][0] * size
        y1 = pastel_colors[fi][1] * size
        x2 = pastel_colors[ti][0] * size
        y2 = pastel_colors[ti][1] * size
        draw.line([(x1, y1), (x2, y2)], fill=edge_color, width=edge_width)

    # Draw nodes
    for xf, yf, hex_color, rf in pastel_colors:
        x, y = xf * size, yf * size
        r = rf * size
        # Parse hex color
        hc = hex_color.lstrip("#")
        rgb = tuple(int(hc[i : i + 2], 16) for i in (0, 2, 4))
        fill = rgb + (230,)
        outline = (255, 255, 255, 200)
        draw.ellipse(
            [x - r, y - r, x + r, y + r],
            fill=fill,
            outline=outline,
            width=int(size * 0.004),
        )


def draw_magnifier(draw: ImageDraw.Draw, size: int):
    """Draw a magnifying glass in the bottom-right quadrant."""
    # Lens center and radius
    lcx, lcy = size * 0.72, size * 0.74
    lr = size * 0.10
    outline_color = (255, 255, 255, 200)
    lens_fill = (255, 255, 255, 25)
    handle_color = (220, 220, 220, 200)
    width = int(size * 0.008)

    # Lens circle
    draw.ellipse(
        [lcx - lr, lcy - lr, lcx + lr, lcy + lr],
        fill=lens_fill,
        outline=outline_color,
        width=width,
    )

    # Handle extending toward bottom-right corner
    angle = math.pi / 4  # 45 degrees
    hx1 = lcx + lr * math.cos(angle)
    hy1 = lcy + lr * math.sin(angle)
    handle_len = size * 0.10
    hx2 = hx1 + handle_len * math.cos(angle)
    hy2 = hy1 + handle_len * math.sin(angle)
    draw.line([(hx1, hy1), (hx2, hy2)], fill=handle_color, width=int(size * 0.018))

    # Handle end cap
    cap_r = size * 0.012
    draw.ellipse(
        [hx2 - cap_r, hy2 - cap_r, hx2 + cap_r, hy2 + cap_r], fill=handle_color
    )


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

# Standard macOS icon sizes: (points, scale) -> pixel size
MACOS_ICON_SIZES = [
    (16, 1),
    (16, 2),
    (32, 1),
    (32, 2),
    (128, 1),
    (128, 2),
    (256, 1),
    (256, 2),
    (512, 1),
    (512, 2),
]


def render_icon(size: int) -> Image.Image:
    """Render the icon at the given pixel size and return as RGB Image."""
    radius = int(size * 0.18)

    # Layer 1: Gradient background
    top_color = (2, 48, 58, 255)  # #02303A
    bottom_color = (27, 169, 76, 255)  # #1BA94C
    bg, mask = draw_gradient(None, size, top_color, bottom_color, radius)

    # Composite onto transparent canvas
    icon = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    icon.paste(bg, mask=mask)

    # Layer 2: Elephant watermark
    elephant_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_elephant(ImageDraw.Draw(elephant_layer), size)
    icon = Image.alpha_composite(icon, elephant_layer)

    # Layer 3: Dependency graph
    graph_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_graph(ImageDraw.Draw(graph_layer), size)
    icon = Image.alpha_composite(icon, graph_layer)

    # Layer 4: Magnifying glass
    mag_layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw_magnifier(ImageDraw.Draw(mag_layer), size)
    icon = Image.alpha_composite(icon, mag_layer)

    # Flatten to RGB
    final = Image.new("RGB", (size, size), (0, 0, 0))
    final.paste(icon, mask=icon.split()[3])
    return final


def icon_filename(points: int, scale: int) -> str:
    """Return the filename for a given icon size."""
    if scale == 1:
        return f"icon_{points}x{points}.png"
    return f"icon_{points}x{points}@{scale}x.png"


def generate_icons(output_dir: str):
    """Generate all macOS icon sizes into output_dir."""
    # Render once at 1024 and downscale for each size
    master = render_icon(1024)

    os.makedirs(output_dir, exist_ok=True)
    for points, scale in MACOS_ICON_SIZES:
        px = points * scale
        resized = master.resize((px, px), Image.LANCZOS)
        path = os.path.join(output_dir, icon_filename(points, scale))
        resized.save(path, "PNG")
        print(f"  {icon_filename(points, scale)} ({px}x{px})")

    print(f"Icons saved to {output_dir}")


if __name__ == "__main__":
    default_dir = os.path.join(
        os.path.dirname(os.path.dirname(os.path.abspath(__file__))),
        "GradleDependencyVisualizer",
        "Assets.xcassets",
        "AppIcon.appiconset",
    )
    output = sys.argv[1] if len(sys.argv) > 1 else default_dir
    generate_icons(output)
