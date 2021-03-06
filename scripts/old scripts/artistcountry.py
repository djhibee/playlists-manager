from beets.plugins import BeetsPlugin
from musicbrainzngs.musicbrainz import get_artist_by_id

class CountryPlugin(BeetsPlugin):
    pass

def memoize_artist(f):
    cache = {}
    def memf(item):
        artist_id = item['mb_artistid']
        if artist_id not in cache:
            cache[artist_id] = f(item)
        return cache[artist_id]
    return memf

@CountryPlugin.template_field('artist_country')
@memoize_artist
def _tmpl_country(item):
    forbiddenString = {u''}
    print repr('in countryartist')
    print repr(item['mb_artistid'])
    if item['mb_artistid'] not in forbiddenString:
        print repr('processing artist')
        artist_item = get_artist_by_id(item['mb_artistid'])
        artist_country = artist_item['artist'].get('country', '')
        if not artist_country:
            my_country = raw_input("Enter country (not found in musicbrainz): ")
            return my_country
        return artist_country.upper()
    my_country = raw_input("Enter country (not found in musicbrainz): ")
    return my_country
