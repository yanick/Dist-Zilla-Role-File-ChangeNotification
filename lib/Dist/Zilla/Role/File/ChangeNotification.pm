use strict;
use warnings;
package Dist::Zilla::Role::File::ChangeNotification;
# ABSTRACT: Receive notification when something changes a file's contents
# vim: set ts=8 sw=4 tw=78 et :

use Moose::Role;
use Digest::MD5 'md5_hex';
use Encode 'encode_utf8';
use namespace::autoclean;

has _content_checksum => ( is => 'rw', isa => 'Str' );

has on_changed => (
    is => 'rw',
    isa => 'CodeRef',
    traits => ['Code'],
    handles => { has_changed => 'execute_method' },
    lazy => 1,
    default => sub {
        sub { die 'content of ', shift->name, ' has changed!' }
    },
);

sub watch_file
{
    my $self = shift;

    return if $self->_content_checksum;

    # this may not be the correct encoding, but things should work out okay
    # anyway - all we care about is deterministically getting bytes back
    $self->_content_checksum($self->__calculate_checksum);
    return;
}

sub __calculate_checksum
{
    my $self = shift;
    md5_hex(encode_utf8($self->content))
}

around content => sub {
    my $orig = shift;
    my $self = shift;

    # pass through if getter
    return $self->$orig if @_ < 1;

    my $content = shift;
    $self->$orig($content);

    # do nothing extra if we haven't got a checksum yet
    my $old_checksum = $self->_content_checksum;
    return $content if not $old_checksum;

    $self->has_changed($content) if $self->__calculate_checksum ne $old_checksum;
    return $content;
};

1;
__END__

=pod

=head1 SYNOPSIS

    package Dist::Zilla::Plugin::MyPlugin;
    sub some_phase
    {
        my $self = shift;

        my ($source_file) = grep { $_->name eq $self->source } @{$self->zilla->files};
        # ... do something with this file ...

        Dist::Zilla::Role::File::ChangeNotification->meta->apply($source_file);
        my $plugin = $self;
        $file->on_changed(sub {
            $plugin->log_fatal('someone tried to munge ', shift->name,
                ' after we read from it. You need to adjust the load order of your plugins.');
        });
        $file->watch_file;
    }

=head1 DESCRIPTION

This is a role for L<Dist::Zilla::Role::File> objects which gives you a
mechanism for detecting and acting on files changing their content. This is
useful if your plugin performs an action based on a file's content (perhaps
copying that content to another file), and then later in the build process,
that source file's content is later modified.

=head1 ATTRIBUTES

=over 4

=item * C<on_changed>: a sub which is invoked against the file when the file's
content has changed.  The new file content is passed as an argument.  If you
need to do something in your plugin at this point, define the sub as a closure
over your plugin object, as demonstrated in the L</SYNOPSIS>.

=back

=head1 METHODS

=over 4

=item * C<watch_file> - Once this method is called, every subsequent change to
the file's content will result in your C<on_changed> sub being invoked against
the file.  The new content is passed as the argument to the sub; The return
value is ignored.

=back

=head1 SUPPORT

=for stopwords irc

Bugs may be submitted through L<the RT bug tracker|https://rt.cpan.org/Public/Dist/Display.html?Name=Dist-Zilla-Role-File-ChangeNotification>
(or L<bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org|mailto:bug-Dist-Zilla-Role-File-ChangeNotification@rt.cpan.org>).
I am also usually active on irc, as 'ether' at C<irc.perl.org>.

=head1 SEE ALSO

=begin :list

* L<Dist::Zilla::File::OnDisk>
* L<Dist::Zilla::File::InMemory>

=end :list

=cut
