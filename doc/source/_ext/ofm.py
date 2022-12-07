import os

def build_init(app):
    os.symlink(app.srcdir + '/../../build', app.srcdir + '/build')
    os.symlink(app.srcdir + '/../../comp', app.srcdir + '/comp')

def build_finish(app, exception):
    os.remove(app.srcdir + '/build')
    os.remove(app.srcdir + '/comp')

def setup(app):
    app.connect('builder-inited', build_init)
    app.connect('build-finished', build_finish)

    return {
        'version': '0.1',
        'parallel_read_safe': True,
        'parallel_write_safe': True,
    }
