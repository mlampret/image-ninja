# Mojolicious::Plugin::ImageNinja
Mojolicious plugin to manipulate images on the fly


## Example usage:

In your app startup

```
$self->plugin('image_ninja');
```

In a template:

```
<img src="/imageninja/resize:300x200;contrast:1.3/https://raw.githubusercontent.com/kraih/perl-raptor/master/example.png">
<img src="/imageninja/resize:x100;contrast:0.4/https://raw.githubusercontent.com/kraih/perl-raptor/master/example.png">
```
