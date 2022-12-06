# How to get test data?
# Add code below on app/models/project.rb instead of send to ractor.
# And run the StoreAnnotationsCollectionUploadJob.
# Then data is saved into the tmp direcotry.
# path = Dir.mktmpdir('send_data', './tmp')
# File.open("#{path}/#{doc.sourcedb}_#{doc.sourceid}", "wb", 0755) do |f|
# send_data = Marshal.dump({
#   index: index,
#   ref_text: ref_text,
#   options: options,
#   data:data
# })
# f.write(send_data)
# end

require 'benchmark'
require 'text_alignment'
require 'active_support'
require_relative 'config/initializers/ractor.rb'

MAX=16

test_data = Dir["./tmp/send_data20221122-2664*/*"].map do |file|
  Marshal.load(File.binread(file))
end

time = Benchmark.realtime do
  pipe = Ractor.new do
    loop do
      Ractor.yield Ractor.receive
    end
  end

  workers = (1..MAX).map do
    Ractor.new pipe do |pipe|
      while msg = pipe.take
        aligner = TextAlignment::TextAlignment.new(msg[:ref_text], msg[:options])
        results = msg[:data].map do |datum|
          begin
            aligner.align(datum[:text], datum[:denotations] + datum[:blocks])

            {
              denotations: aligner.transform_hdenotations(datum[:denotations]),
              blocks: aligner.transform_hdenotations(datum[:blocks]),
              lost_annotations: aligner.lost_annotations,
              block_alignment: aligner.lost_annotations.present? ? aligner.block_alignment : nil
            }
          rescue => e
            break {
              error: e.message
            }
          end
        end

        Ractor.yield(Ractor.make_shareable({
          index: msg[:index],
          results: results
        }), move: true)
      end
    end
  end

  test_data.each do |send_data|
    pipe.send(send_data)
  end.each do
    _r, results = Ractor.select(*workers)
  end
end

p MAX, time
