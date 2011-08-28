# author : 	http://wiki.openqa.org/display/~jarkelen
#		http://wiki.openqa.org/display/~vinumams
# adaptation	david GUENAULT dguenault at monitoring-fr dot org
# this class was originaly published on http://wiki.openqa.org/display/WTR/HTML+report+class

class Report
  # Initialize the report class
  def initialize()
    @overallResult = 'PASSED'
    @reportContent1 = ''
    @reportContent2 = ''
    @reportCapture = ''
  end

  # Create a report
  def createReport(reportName)
    # Get current time
    t = Time.now

    # Format the day
    if(t.day.to_s.length == 1)
      strDay = '0' + t.day.to_s
    else
      strDay = t.day.to_s
    end

    # Format the month
    if(t.month.to_s.length == 1)
      strMonth = '0' + t.month.to_s
    else
      strMonth = t.month.to_s
    end

    # Format the year
    strYear = t.year.to_s

    # Format the hour
    if(t.hour.to_s.length == 1)
      strHour = '0' + t.hour.to_s
    else
      strHour = t.hour.to_s
    end

    # Format the minutes
    if(t.min.to_s.length == 1)
      strMinutes = '0' + t.min.to_s
    else
      strMinutes = t.min.to_s
    end

    # Format the seconds
    if(t.sec.to_s.length == 1)
      strSeconds = '0' + t.sec.to_s
    elsif (t.sec.to_s.length == 0)
      strSeconds = '00'
    else
      strSeconds = t.sec.to_s
    end

    # Create the report name
    strTime = '_' + strDay + strMonth + strYear + '_' + strHour + strMinutes + strSeconds + '.html'
    strNiceTime = strDay + '-' + strMonth + '-' + strYear + ' @ ' + strHour + ':' + strMinutes + ':' + strSeconds
    strTotalReport = reportName + strTime

    # Create the HTML report
    strFile = File.open(strTotalReport, 'w')

    # Format the header of the HTML report
    @reportContent1 = '<html>
      <head>
      <meta content=text/html; charset=ISO-8859-1 http-equiv=content-type>
      <title>QA Test Report</title>
      <style type=text/css>
      .title { font-family: verdana; font-size: 30px;  font-weight: bold; align: left; color: #045AFD;}
      .bold_text { font-family: verdana; font-size: 12px;  font-weight: bold;}
      .normal_text { font-family: verdana; font-size: 12px;  font-weight: normal;}
      .small_text { font-family: verdana; font-size: 10px;  font-weight: normal; }
      .border { border: 1px solid #045AFD;}
      .border_left { border-top: 1px solid #045AFD; border-left: 1px solid #045AFD; border-right: 1px solid #045AFD;}
      .border_right { border-top: 1px solid #045AFD; border-right: 1px solid #045AFD;}
      .result_ok { font-family: verdana; font-size: 12px;  font-weight: bold; text-align: center; color: green;}
      .result_nok { font-family: verdana; font-size: 12px;  font-weight: bold; text-align: center; color: red;}
      .overall_ok { font-family: verdana; font-size: 12px;  font-weight: bold; text-align: left; color: green;}
      .overall_nok { font-family: verdana; font-size: 12px;  font-weight: bold; text-align: left; color: red;}
      .bborder_left { border-top: 1px solid #045AFD; border-left: 1px solid #045AFD; border-bottom: 1px solid #045AFD; background-color:#045AFD;font-family: verdana; font-size: 12px;  font-weight: bold; text-align: center; color: white;}
      .bborder_right { border-right: 1px solid #045AFD; background-color:#045AFD;font-family: verdana; font-size: 12px;  font-weight: bold; text-align: center; color: white;}
      </style>
      </head>
      <body>
      <br>
      <center>
      <table width=800 border=0 cellpadding=2 cellspacing=2>
      <tbody>
      <tr>
      <td>
      <table width=100% border=0 cellpadding=2 cellspacing=2>
      <tbody>
      <tr>
      <td style=width: 150px;>&nbsp;</td>
      <td align=right><p class=title>'+$REPORTTITLE+'</p></td>
      </tr>
      </tbody>
      </table>
      <br>
      <hr width=100% class=border size=1px>
      <br>
      <br>
      <center>
      <table border=0 width=95% cellpadding=2 cellspacing=2>
      <tbody>
      <tr>
      <td width=20%><p class=bold_text>Report Name</p></td>
      <td width=5%><p class=bold_text>:</p></td>
      <td width=75%><p class=normal_text>' + strTotalReport + '</p></td>
      </tr>
      <tr>
      <td width=20%><p class=bold_text>Test Execution</p></td>
      <td width=5%><p class=bold_text>:</p></td>
      <td width=75%><p class=normal_text>' + strNiceTime + '</p></td>
      </tr>
      <tr>
      <td width=20%><p class=bold_text>Overall Result</p></td>
      <td width=5%><p class=bold_text>:</p></td>'

    @reportContent2 = '</tr>
      </tbody>
      </table>
      </center>
      <br><br>
      <center>
      <table width=95% cellpadding=2 cellspacing=0>
      <tbody>
      <tr>
      <td class=bborder_left width=30%><p>Test Step</p></td>
      <td class=bborder_left width=10%><p>Result</p></td>
      <td class=bborder_right width=60%><p>Execution time</p></td>
      </tr>'

    # Close the report
    strFile.close

    return strTotalReport
  end

  def addtoReport(reportName, step, result, exectime,capture="")
    @reportContent2 = @reportContent2 + '<tr><td class=border_left width=30%><p class=normal_text>' + step + '</p></td>'
    if ( capture != "")
	@reportCapture=capture
    end

    # Format the body of the HTML report
    if (result == 'PASSED')
      @reportContent2 = @reportContent2 + '<td class=border_right width=10%><p class=result_ok>' + result + '</p></td>'
    else
      @overallResult = 'FAILED'
      @reportContent2 = @reportContent2 + '<td class=border_right width=10%><p class=result_nok>' + result + '</p></td>'
    end

    @reportContent2 = @reportContent2 + '<td class=border_right width=60%><p class=normal_text>' + exectime + '</p></td></tr>'
  end

  def finishReport(reportName)
    # Open the HTML report
    strFile = File.open(reportName, 'a')

    # Format the footer of the HTML report
    @reportContent2 = @reportContent2 + '<tr>
      <td class=bborder_left width=30%><p>&nbsp;</p></td>
      <td class=bborder_left width=10%><p>&nbsp;</p></td>
      <td class=bborder_right width=60%><p>&nbsp;</p></td>
      </tr>
      </table>
      <br><br>
      <hr width=100% class=border size=1px>
      <br>
      <center><p class=small_text>&copy http://www.monitoring-fr.org 201</p></center>
      <br>'

    strFile.puts(@reportContent1)

    if (@overallResult == 'PASSED')
      strFile.puts('<td width=75%><p class=overall_ok>' + @overallResult + '</p></td>')
    else
      strFile.puts('<td width=75%><p class=overall_nok>' + @overallResult + '</p></td>')
    end

    strFile.puts(@reportContent2)

    # Close the report
    strFile.close
  end
end
