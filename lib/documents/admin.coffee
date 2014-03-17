class @ArXivPDF extends Document
  # key: key (filename) of the tar file containing PDFs
  # lastModified: last modified timestamp of the file
  # eTag: eTag for the file as provided by S3
  # size: size of the file
  # processingStart: timestamp when processing started
  # processingEnd: timestamp when precessing ended
  # PDFs: a list of processed PDFs in this file:
  #   id
  #   path
  #   size
  #   mtime

  @Meta
    name: 'ArXivPDF'
