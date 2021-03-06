describe FastlaneCore do
  describe FastlaneCore::CommandExecutor do
    describe "execute" do
      it 'executes a simple command successfully' do
        unless FastlaneCore::Helper.windows?
          expect(Process).to receive(:wait)
        end

        result = FastlaneCore::CommandExecutor.execute(command: 'echo foo')

        expect(result).to eq('foo')
      end

      it 'handles reading which throws a EIO exception' do
        explodes_on_strip = 'danger! lasers!'
        fake_std_in = ['a_filename', explodes_on_strip]

        # This is really raised by the `each` call, but for easier mocking
        # we raise when the line is cleaned up with `strip` afterward
        expect(explodes_on_strip).to receive(:strip).and_raise(Errno::EIO)

        # Make a fake child process so we have a valid PID and $? is set correctly
        child_process_id = 1
        expect(FastlaneCore::FastlanePty).to receive(:spawn) do |command, &block|
          expect(command).to eq('ls')
          block.yield(fake_std_in, 'not_really_std_out', child_process_id)
          $?.exitstatus
        end

        result = FastlaneCore::CommandExecutor.execute(command: 'ls')

        # We are implicitly also checking that the error was not rethrown because that would
        # have crashed the test
        expect(result).to eq('a_filename')
      end
    end

    describe "which" do
      require 'tempfile'

      it "does not find commands which are not on the PATH" do
        expect(FastlaneCore::CommandExecutor.which('not_a_real_command')).to be_nil
      end

      it "finds commands without extensions which are on the PATH" do
        Tempfile.open('foobarbaz') do |f|
          File.chmod(0777, f)

          temp_dir = File.dirname(f)
          temp_cmd = File.basename(f)

          with_env_values('PATH' => temp_dir) do
            expect(FastlaneCore::CommandExecutor.which(temp_cmd)).to eq(f.path)
          end
        end
      end

      it "finds commands with known extensions which are on the PATH" do
        Tempfile.open(['foobarbaz', '.exe']) do |f|
          File.chmod(0777, f)

          temp_dir = File.dirname(f)
          temp_cmd = File.basename(f, '.exe')

          with_env_values('PATH' => temp_dir, 'PATHEXT' => '.exe') do
            expect(FastlaneCore::CommandExecutor.which(temp_cmd)).to eq(f.path)
          end
        end
      end

      it "does not find commands with unknown extensions which are on the PATH" do
        Tempfile.open(['foobarbaz', '.exe']) do |f|
          File.chmod(0777, f)

          temp_dir = File.dirname(f)
          temp_cmd = File.basename(f, '.exe')

          with_env_values('PATH' => temp_dir, 'PATHEXT' => '') do
            expect(FastlaneCore::CommandExecutor.which(temp_cmd)).to be_nil
          end
        end
      end
    end
  end
end
