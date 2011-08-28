require 'rubygems'
require 'test/unit'
require 'watir-webdriver'
require 'Report'

class TC_Check_watir < Test::Unit::TestCase

	$start=0
	$end=0
	$current=""
	
	$perfdata=""
	$output=""
	$code=0
	$failed=0
	$success=0
	$total=0
	$report
	$testReport

	####################################################
	# Do not modify this !
	####################################################
	
	def test_0_before
		$report = Report.new()
  		$testReport = $report.createReport($REPORT)

		$browser = Watir::Browser.new
		$current=""
	end
	
	def test_999_after
		$current=""
		$report.finishReport($testReport)
		if $code == 2
			$output="[CRITICAL] "+$failed.to_s()+"/"+$total.to_s()+" test(s) failed "
		else
			$output="[OK] All tests are ok"
		end
		
		puts $output+" |"+$perfdata
		#$browser.close
		exit($code)
	end
	
	def setup
		# this is exectuted before each test
		$start=Time.now.to_i
	end
	
	def teardown
		# this is executed after each test
		
		# first check result
		$end=Time.now.to_i
		$timer=$end-$start
			
		if $current != ""
			$perfdata = $perfdata + " " + $current + "=" + $timer.to_s() + "s;;;;" + " "
		end
			
		$start=0
		$end=0
		$timer=0
	end
	
	private

	def textPresent(text)
		present = $browser.text.include?(text)
		
		$total=$total+1
		if not present 
			$code = 2
			$failed=$failed+1
			$sc=$REPORT+"_"+$current+Time.now.to_i.to_s()+".png"
			$browser.driver.save_screenshot($sc)
			$report.addtoReport($testReport, $current, 'FAILED', $timer.to_s+"s",$sc)
		else
			$success=$success+1
			$report.addtoReport($testReport, $current, 'PASSED', $timer.to_s+"s")
		end
	end
end
