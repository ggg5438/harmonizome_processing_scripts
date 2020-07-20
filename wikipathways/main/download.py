import time
import urllib

folder = 'input/'
date = time.strftime('%Y%m%d', time.localtime())
fileurl = 'http://www.pathvisio.org/data/bots/gmt/wikipathways.gmt' # 20/7/2020 now the server is closed.
filename = 'dataset_{}_original.gmt'.format(date)
urllib.request.urlretrieve(fileurl, folder + filename)
