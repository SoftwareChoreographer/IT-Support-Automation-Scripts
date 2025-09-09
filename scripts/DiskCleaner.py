#!/usr/bin/env python3
"""
DiskCleaner.py
---------------
Professional disk cleanup utility for IT support.
Safely removes temporary files and cache data.
Logs all operations to timestamped files in disk_cleanup_logs.
"""

import os
import shutil
import argparse
import logging
from pathlib import Path
import sys
import platform
import time
from datetime import datetime

class DiskCleaner:
    """Disk cleanup utility with safety features and file logging."""

    def __init__(self, dry_run=True, verbose=False, log_dir=None):
        self.dry_run = dry_run
        self.verbose = verbose
        self.freed_space = 0
        self.cleaned_files = 0
        self.skipped_files = 0
        self.protected_paths = self.get_protected_paths()
        self.setup_logging(log_dir)

    def setup_logging(self, log_dir):
        """Setup logging for console and file."""
        if not log_dir:
            log_dir = Path.home() / "disk_cleanup_logs"
        self.log_dir = Path(log_dir)
        self.log_dir.mkdir(exist_ok=True)

        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = self.log_dir / f"disk_cleanup_{timestamp}.log"

        log_level = logging.DEBUG if self.verbose else logging.INFO
        logging.basicConfig(
            level=log_level,
            format="%(asctime)s - %(levelname)s - %(message)s",
            handlers=[
                logging.StreamHandler(sys.stdout),
                logging.FileHandler(log_file)
            ]
        )
        self.log_file = log_file
        logging.info(f"Log file: {self.log_file}")

    def get_protected_paths(self):
        """Return a list of system-critical paths to never delete."""
        system = platform.system()
        protected = []

        if system == "Windows":
            protected = [
                Path(os.environ.get("SystemRoot", r"C:\Windows")),
                Path(os.environ.get("ProgramFiles", r"C:\Program Files")),
                Path(os.environ.get("ProgramFiles(x86)", r"C:\Program Files (x86)")),
            ]
        elif system in ["Linux", "Darwin"]:
            protected = [
                Path("/bin"), Path("/sbin"), Path("/usr"), Path("/etc"),
                Path("/lib"), Path("/var"), Path("/System"), Path("/")
            ]
        return [p.resolve() for p in protected]

    def is_protected(self, path: Path):
        """Check if a path is protected and should not be deleted."""
        try:
            path_resolved = path.resolve()
            for protected in self.protected_paths:
                if path_resolved == protected or protected in path_resolved.parents:
                    return True
        except Exception:
            return True
        return False

    def get_directory_size(self, directory_path):
        """Calculate total size of all files in directory."""
        total_size = 0
        try:
            for entry in os.scandir(directory_path):
                if entry.is_file():
                    try:
                        total_size += entry.stat().st_size
                    except (OSError, PermissionError):
                        pass
                elif entry.is_dir() and not entry.name.startswith('.'):
                    try:
                        total_size += self.get_directory_size(entry.path)
                    except (OSError, PermissionError):
                        pass
        except (OSError, PermissionError):
            pass
        return total_size

    def safe_remove(self, path: Path):
        """Safely remove file or directory."""
        if self.is_protected(path):
            logging.warning(f"Skipping protected path: {path}")
            self.skipped_files += 1
            return 0

        try:
            if path.is_file():
                size = path.stat().st_size
                if not self.dry_run:
                    path.unlink()
                    logging.info(f"Removed file: {path} ({self.human_readable(size)})")
                else:
                    logging.info(f"[DRY-RUN] Would remove file: {path} ({self.human_readable(size)})")
                self.freed_space += size
                self.cleaned_files += 1
                return size

            elif path.is_dir():
                size = self.get_directory_size(path)
                if not self.dry_run:
                    shutil.rmtree(path)
                    logging.info(f"Removed directory: {path} ({self.human_readable(size)})")
                else:
                    logging.info(f"[DRY-RUN] Would remove directory: {path} ({self.human_readable(size)})")
                self.freed_space += size
                self.cleaned_files += 1
                return size

        except PermissionError:
            logging.warning(f"Permission denied: {path}")
            self.skipped_files += 1
        except FileNotFoundError:
            pass
        except Exception as e:
            logging.warning(f"Error processing {path}: {str(e)}")
            self.skipped_files += 1

        return 0

    def human_readable(self, size_bytes):
        """Convert bytes to human-readable format."""
        if size_bytes == 0:
            return "0 B"
        units = ['B', 'KB', 'MB', 'GB', 'TB']
        index = 0
        size = float(size_bytes)
        while size >= 1024 and index < len(units) - 1:
            size /= 1024
            index += 1
        return f"{size:.2f} {units[index]}"

    def get_target_paths(self):
        """Get platform-specific cleanup targets."""
        system = platform.system()
        targets = []

        if system == "Windows":
            windows_targets = [
                os.environ.get("TEMP", r"C:\Windows\Temp"),
                Path(os.environ.get("LOCALAPPDATA", "")) / "Temp",
            ]
            targets.extend([Path(t) for t in windows_targets if t])

        elif system in ["Linux", "Darwin"]:
            unix_targets = [Path("/tmp"), Path("/var/tmp"), Path.home() / ".cache"]
            targets.extend(unix_targets)

        # Filter out non-existent or protected paths
        safe_targets = [path for path in targets if path.exists() and not self.is_protected(path)]
        return safe_targets

    def cleanup(self):
        """Main cleanup procedure."""
        logging.info("Disk Cleanup Utility - Started")
        logging.info(f"Dry run mode: {'Yes' if self.dry_run else 'No'}")

        targets = self.get_target_paths()
        if not targets:
            logging.warning("No valid cleanup targets found")
            return False

        logging.info(f"Processing {len(targets)} cleanup targets")
        for target in targets:
            if target.is_dir():
                initial_size = self.get_directory_size(target)
                if initial_size > 0:
                    logging.info(f"Processing: {target} (Size: {self.human_readable(initial_size)})")
                    for item in target.iterdir():
                        self.safe_remove(item)
        return True


def main():
    parser = argparse.ArgumentParser(description="Professional disk cleanup utility")
    parser.add_argument("--dry-run", action="store_true", help="Preview cleanup without deleting files (default)")
    parser.add_argument("--verbose", "-v", action="store_true", help="Enable verbose output")
    parser.add_argument("--force", action="store_true", help="Actually perform deletion")
    args = parser.parse_args()

    dry_run = not args.force

    print("DiskCleaner - Professional Disk Cleanup Utility")
    print("=" * 50)

    if dry_run:
        print("DRY RUN MODE: No files will be deleted")
        print("Use --force to actually perform cleanup")
    else:
        print("LIVE MODE: Files will be permanently deleted")
        print("Press Ctrl+C within 3 seconds to cancel...")
        try:
            time.sleep(3)
        except KeyboardInterrupt:
            print("\nOperation cancelled by user")
            return 1

    cleaner = DiskCleaner(dry_run=dry_run, verbose=args.verbose)

    try:
        success = cleaner.cleanup()

        print("\n" + "=" * 50)
        print("CLEANUP RESULTS")
        print("=" * 50)
        print(f"Space {'that would be freed' if dry_run else 'freed'}: {cleaner.human_readable(cleaner.freed_space)}")
        print(f"Files processed: {cleaner.cleaned_files + cleaner.skipped_files}")
        print(f"  {'Would be cleaned' if dry_run else 'Cleaned'}: {cleaner.cleaned_files}")
        print(f"  {'Would be skipped' if dry_run else 'Skipped'}: {cleaner.skipped_files}")
        if dry_run:
            print("\nThis was a dry run. Use --force to actually clean files.")
        else:
            print("\nCleanup completed successfully!")

        logging.info("Cleanup completed successfully.")
        logging.info(f"Total freed space: {cleaner.human_readable(cleaner.freed_space)}")
        return 0 if success else 1

    except KeyboardInterrupt:
        print("\nCleanup interrupted by user")
        logging.warning("Cleanup interrupted by user")
        return 1
    except Exception as e:
        print(f"\nError during cleanup: {str(e)}")
        logging.error(f"Error during cleanup: {str(e)}")
        return 1


if __name__ == "__main__":
    sys.exit(main())
