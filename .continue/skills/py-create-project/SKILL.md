# Create Python Project

Create a new Python library project managed by **uv**, using the src layout.
Includes pytest for testing and the scientific stack (numpy/scipy/matplotlib/pandas)
by default. No CLI by default.

## When to use
- User asks to create a new Python project / library / package
- User asks to scaffold or initialize a Python codebase with uv

## Inputs to ask user (if not specified)
- Project name (required). The Python package name is the project name with
  `-` replaced by `_` (uv does this automatically).
- Python version requirement (default: whatever `uv` picks, typically latest stable)
- Include CLI with Typer? (default: **no**; only if the user explicitly asks)
- Include tests with pytest? (default: **yes**)

## Steps

### 1. Scaffold

Run inside the target parent directory:

```bash
uv init --lib <project-name>
```

This generates:

```
<project-name>/
├── pyproject.toml
├── README.md
├── .python-version
├── src/<package_name>/
│   └── __init__.py
└── tests/
    └── __init__.py
```

Then create a `notebooks/` directory with a default demo notebook:

```bash
mkdir -p <project-name>/notebooks
```

Create `notebooks/demo.ipynb` (nbformat 4 JSON) with a markdown intro cell
and a code cell that imports and calls the sample function:

```python
from <package_name> import hello

print(hello())
```

### 2. Add dependencies

```bash
cd <project-name>
uv add --dev pytest              # skip if user declines tests
uv add numpy scipy matplotlib pandas   # scientific stack, always
uv add --dev jupyterlab ipykernel      # notebook support, always
```

Only if the user explicitly asks for a CLI:

```bash
uv add typer
```

### 3. Adjust the generated files

- **`src/<package_name>/__init__.py`**: replace the boilerplate with a
  minimal public API, e.g.:

  ```python
  """<project-name>: one-line description."""

  __version__ = "0.1.0"

  def hello() -> str:
      """Sample function; adapt to the user's use case."""
      return "Hello from <project-name>!"

  __all__ = ["hello", "__version__"]
  ```

- **`pyproject.toml`**: verify/fill in:
  - `description` in `[project]`
  - `[project.scripts]` entry if CLI is requested:

    ```toml
    [project.scripts]
    <project-name> = "<package_name>.cli:app"
    ```

- **`src/<package_name>/cli.py`** (only if CLI requested), a Typer app:

  ```python
  import typer

  app = typer.Typer(help="<project-name> command line interface.")


  @app.command()
  def hello(name: str = typer.Option("world", help="Name to greet.")) -> None:
      """Greet someone."""
      typer.echo(f"Hello, {name}!")


  if __name__ == "__main__":
      app()
  ```

- **`tests/test_core.py`** (only if tests included):

  ```python
  from <package_name> import hello


  def test_hello():
      assert hello() == "Hello from <project-name>!"
  ```

  Remove the generated `tests/__init__.py` (pytest does not need it).

- **`.gitignore`**: create a dedicated one in the project root (uv's
  `--lib` template may not include one) with at least:

  ```gitignore
  # Python
  __pycache__/
  *.py[cod]
  *.egg-info/
  dist/
  build/

  # Virtual environments
  .venv/

  # Testing / tooling caches
  .pytest_cache/
  .ruff_cache/
  .mypy_cache/
  .coverage
  htmlcov/

  # Jupyter
  .ipynb_checkpoints/

  # Editors / OS
  .vscode/
  .idea/
  .DS_Store
  ```

- **`README.md`**: short usage section (install, run tests; run CLI if requested).

### 4. Sync and verify

```bash
uv sync
uv run pytest          # if tests included
uv run <project-name> hello   # only if CLI requested
```

All commands must pass. Report the created structure and how to run/test.

### 5. Notebooks

`notebooks/` holds Jupyter notebooks (`.ipynb`) and is not part of the
installed package. With `jupyterlab`/`ipykernel` installed (step 2),
notebooks run with the project's virtual environment as the kernel
(VS Code: Select Kernel → pick the project's `.venv`).

## Conventions

- Do NOT initialize a git repository — uv may create one depending on its
  config; if it does, leave it, but do not commit.
- Never edit `uv.lock` manually; it is managed by `uv add`/`uv sync`.
- Package code lives only under `src/<package_name>/`; tests live in `tests/`.
- Keep the sample `hello()` function minimal — adapt it to the user's
  stated use case when known. If a CLI was requested, keep the Typer
  `hello` command minimal too.
