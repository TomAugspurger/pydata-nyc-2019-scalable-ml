FROM jupyter/base-notebook

USER root

RUN apt-get update \
  && apt-get install -yq --no-install-recommends graphviz git \
  && apt-get clean \
  && rm -rf /var/lib/apt/lists/*

USER $NB_USER

RUN conda install --yes --freeze-installed \
    -c conda-forge \
    python=3.7 \
    python-blosc \
    cytoolz \
    dask==2.6.0 \
    nomkl \
    numpy==1.17.2 \
    pandas==0.25.2 \
    ipywidgets \
    dask-labextension==1.0.3 \
    python-graphviz \
    s3fs \
    gcsfs \
    dask-ml \
    pyarrow \
    fastparquet \
    python-snappy \
    umap-learn \
    py-xgboost \
    dask-xgboost \
    dask-kubernetes \
    git \
    tpot \
    matplotlib \
    && jupyter labextension install @jupyter-widgets/jupyterlab-manager@1.0.1 dask-labextension@1.0.1 \
    && conda clean -tipsy \
    && jupyter lab clean \
    && jlpm cache clean \
    && npm cache clean --force \
    && find /opt/conda/ -type f,l -name '*.a' -delete \
    && find /opt/conda/ -type f,l -name '*.pyc' -delete \
    && find /opt/conda/ -type f,l -name '*.js.map' -delete \
    && find /opt/conda/lib/python*/site-packages/bokeh/server/static -type f,l -name '*.js' -not -name '*.min.js' -delete \
    && rm -rf /opt/conda/pkgs

USER root

# Create the /opt/app directory, and assert that Jupyter's NB_UID/NB_GID values
# haven't changed.
RUN mkdir /opt/app \
    && if [ "$NB_UID" != "1000" ] || [ "$NB_GID" != "100" ]; then \
        echo "Jupyter's NB_UID/NB_GID changed, need to update the Dockerfile"; \
        exit 1; \
    fi

# Copy over the example as NB_USER. Unfortuantely we can't use $NB_UID/$NB_GID
# in the `--chown` statement, so we need to hardcode these values.
COPY --chown=1000:100 examples/ /home/$NB_USER/examples
COPY prepare.sh /usr/bin/prepare.sh
COPY --chown=1000:100 examples/ /tmp/examples
COPY dask_config.yaml /tmp/dask_config.yaml

USER $NB_USER

ENTRYPOINT ["tini", "--", "/usr/bin/prepare.sh"]
CMD ["start.sh", "jupyter", "lab"]

