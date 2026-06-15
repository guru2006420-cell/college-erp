from django.contrib.staticfiles.storage import ManifestStaticFilesStorage


class NonStrictManifestStaticFilesStorage(ManifestStaticFilesStorage):
    """Manifest storage that falls back to original paths when entries are missing.

    Using Django's ManifestStaticFilesStorage directly (not whitenoise's subclass)
    avoids a whitenoise version dependency and works with any whitenoise >= 5.x.
    WhiteNoise handles compression at serve time; this class handles URL hashing.
    """

    manifest_strict = False

    # Vendored .min.css and .min.js files include `sourceMappingURL` comments
    # pointing to .map files we don't ship. Django's post-processor raises
    # ValueError when it tries to hash those missing files. Keep only the
    # CSS url() and @import sub-patterns (first two); drop all sourcemap handling.
    patterns = (("*.css", ManifestStaticFilesStorage.patterns[0][1][:2]),)
