<%@ page pageEncoding="utf-8" import="cz.edhouse.matickets.web.commands.*" contentType="text/csv;charset=UTF-8"%><%

    cz.edhouse.matickets.services.CsvProvider csvProvider = 
            (cz.edhouse.matickets.services.CsvProvider)request.getAttribute("csvProvider");

    TicketReportCommand reportData = (TicketReportCommand)request.getAttribute("csvReportData");

    java.util.Date dateFrom = reportData.getFilter().getDateFrom();
    java.util.Date dateTo = reportData.getFilter().getDateTo();
    
    java.text.SimpleDateFormat df = new java.text.SimpleDateFormat("yyyyMMdd");
    
    response.setHeader("Content-Disposition", "attachment; filename=report_"+df.format(dateFrom)+"-"+df.format(dateTo)+".csv");
    response.addHeader("Pragma", "public");
    response.addHeader("Cache-Control", "max-age=0");
    response.setDateHeader("Expires",0);

    csvProvider.printCsv(out, reportData);
%>