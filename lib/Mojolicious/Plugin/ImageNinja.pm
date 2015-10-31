package Mojolicious::Plugin::ImageNinja;
use Mojo::Base 'Mojolicious::Plugin';

use strict;
use warnings;
use Carp;
use Digest::MD5;
use Imager;
use Mojo::UserAgent;

our $VERSION = '0.1';

my $conf = undef;

sub register {
    my ($self, $app, $args) = @_;

    $conf = $args;

    $conf->{base_url} ||= '/imageninja';
    $conf->{public_tmp_dir_abs} ||= $app->static->paths->[0] . '/imageninja';
    $conf->{public_tmp_dir_rel} ||= '/imageninja';

    $app->helper('image_ninja' => sub {
        my $self       = shift;
        my $class_name = shift || __PACKAGE__;

        unless ($class_name =~ m/[A-Z]/) {
            my $namespace = ref($self->app) . '::';
            $namespace = '' if $namespace =~ m/^Mojolicious::Lite/;
            $class_name = join '' => $namespace, Mojo::ByteStream->new($class_name)->camelize;
        }

        my $e = Mojo::Loader->load_class($class_name);

        Carp::croak "Can't load validator '$class_name': " . $e->message if ref $e;
        Carp::croak "Can't find validator '$class_name'" if $e;
        Carp::croak "Wrong validator '$class_name' isa" unless $class_name->isa($class_name);

        return $class_name->new(%$conf, @_);
    });

    $app->routes
        ->get('/'.$conf->{base_url}.'/*query')
        ->name('imageninja')
        ->to(cb => sub { process(@_) });
}

sub process {
    my $self = shift;

    my ($transformations, $url) = split /\//, $self->param('query'), 2;

    my $source_md5 = Digest::MD5::md5_hex($url);
    my $source_abs = $conf->{public_tmp_dir_abs}.'/in_'.$source_md5;

    unless (-f $source_abs) {
        mkdir $conf->{public_tmp_dir_abs};

        Mojo::UserAgent->new(max_redirects => 10)
            ->get($url)
            ->res->content->asset
            ->move_to($source_abs);
    }

    my $transformed_md5 = Digest::MD5::md5_hex($transformations.$url);
    my $transformed_abs = $conf->{public_tmp_dir_abs}.'/out_'.$transformed_md5;
    my $transformed_rel = $conf->{public_tmp_dir_rel}.'/out_'.$transformed_md5;

    my @transformations = split /;/, $transformations; #/

    my $image = Imager->new;
    $image->read(file => $source_abs);

    for my $transformation (@transformations) {
        my ($action, $params) = split /:/, $transformation, 2;
        $image = __PACKAGE__->$action($image, $params);
    }

    $image->write(file => $transformed_abs, type => 'jpeg') or die $image->errstr;

    $self->reply->static($transformed_rel);
}

sub resize {
    my $module = shift;
    my $image  = shift;
    my $params = shift;

    my ($size_x, $size_y) = split /x/, $params;
    
    return $image->scale(
        type    => 'nonprop',
        xpixels => $size_x,
        ypixels => $size_y,
    );
}

sub bw {
    my $module = shift;
    my $image  = shift;

    return $image->convert(preset => 'gray');
}

sub rgb {
    shift;
    shift->convert(preset => 'rgb');
}

sub rotate {
    my $module = shift;
    my $image  = shift;
    my $params = shift;

    my ($degrees, $bg_color) = split /\:/, $params;
    $degrees  ||= 0;
    $bg_color ||= undef;

    return $image->rotate(
        degrees => $degrees,
        back    => Imager::Color->new("#$bg_color"),
    );
}

sub flip {
    my $module = shift;
    my $image  = shift;
    my $params = shift;

    return $image->flip(dir => $params || 'h');
}

sub mosaic {
    my $module = shift;
    my $image  = shift;
    my $params = shift;

    return $image->filter(type => 'mosaic', size => $params || '20');
}

sub contrast {
    my $module = shift;
    my $image  = shift;
    my $params = shift;

    return $image->filter(type => 'contrast', intensity => $params || '1.5');
}

1;



