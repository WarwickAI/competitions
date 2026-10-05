# Sandbox for final testing. run.sh builds this with the official template
# passed in as the "template" build context.
FROM python:3.13-slim

# raylib (the snake template's renderer) links against X11 even when nothing is drawn
RUN apt-get update && apt-get install -y --no-install-recommends libx11-6 \
    && rm -rf /var/lib/apt/lists/*

# The template's dependencies, plus EXTRA_PACKAGES for anything it leaves
# commented out (e.g. the RL libraries). The CPU-only index means torch skips
# the multi-GB CUDA build, and everything is installed up front because the
# container runs with no network.
ARG EXTRA_PACKAGES=""
COPY --from=template pyproject.toml /tmp/pyproject.toml
RUN python -c "import tomllib; print('\n'.join(tomllib.load(open('/tmp/pyproject.toml', 'rb'))['project']['dependencies']))" > /tmp/requirements.txt \
    && printf '%s\n' $EXTRA_PACKAGES >> /tmp/requirements.txt \
    && pip install --no-cache-dir --extra-index-url https://download.pytorch.org/whl/cpu -r /tmp/requirements.txt

COPY score.py /opt/score.py
RUN useradd --create-home runner
USER runner
ENTRYPOINT ["python", "/opt/score.py"]
