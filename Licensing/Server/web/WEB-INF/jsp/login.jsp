<%@page contentType="text/html" pageEncoding="UTF-8"%><%@
include file="/WEB-INF/jsp/includes/include.jspf"
        %><!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Transitional//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-transitional.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
    <meta http-equiv="Content-Type" content="text/html; charset=UTF-8" />
    <title>www.smsjizdenky.cz</title>
    <link rel="stylesheet" type="text/css" href='<c:url value="/css/login.css"/>' />
    <link rel="shortcut icon" href='<c:url value="/favicon.ico"/>' type="image/x-icon">
    <link rel="icon" href='<c:url value="/favicon.ico"/>' type="image/x-icon">
    <script type="text/javascript">
        //<!--
        function switch_login(type) {
            if (type == 2) {
                document.getElementById('sendButton').style.display = 'none';
                document.getElementById('loginButton').style.display = 'block';
                document.getElementById('hashInput').disabled = false;
                document.getElementById('hashLabel').style.color = 'white';
                document.getElementById('vim').checked = true;
                
            } else if (type == 1) {
            document.getElementById('sendButton').style.display = 'block';
            document.getElementById('loginButton').style.display = 'none';                    
            document.getElementById('hashInput').disabled = true;
            document.getElementById('hashLabel').style.color = '#601010';
            document.getElementById('nevim').checked = true;
        }
    }
    //-->
    </script>
</head>
<body <c:choose>
        <c:when test="${loginData.codeSent}">onload="switch_login(2);"</c:when>
        <c:otherwise>onload="switch_login(1);"</c:otherwise>
    </c:choose>>
    <div style="display: none;" id="holder">
    <div id="top">
        <a href="/" id="sms">SMS Jízdenka<span></span></a>
        <form:form modelAttribute="loginData">
            <h1>Portál pro vystavení daňového dokladu DP m. Ústí nad Labem, a.s.</h1>
            <input type="radio" name="X" id="nevim" checked="checked" onclick="javascript:switch_login(1);"/>
            <label for="nevim">Nevím HASH kód z jízdenky</label>
            <p class="desc">(kód Vám bude zaslán na zadané číslo)</p>
            <input type="radio" name="X" id="vim" onclick="javascript:switch_login(2);"/>
            <label for="vim">Vím HASH kód z jízdenky</label>
            <table>
                <tr><th><spring:message code="public.login.phoneNumber"/></th><td><form:input path="phoneNumber"/></td></tr>
                <tr><th><span id="hashLabel"><spring:message code="public.login.hash"/></span></th><td><form:input path="hash" id="hashInput"/></td></tr>
            </table>
            <input type="submit" name="submit" value='<spring:message code="public.login.submit"/>' id="loginButton"/>
            <input type="submit" name="submit" value='<spring:message code="management.login.sendAccessCode"/>' id="sendButton"/>
            <form:errors path="*" cssClass="messages"/>
        </form:form>
    </div>
    <div id="content">
        <h1>Nápověda</h1>
        <h2>Krok č.1</h2>
        <p>Vyberte variantu přihlášení</p>
        <ul>
            <li><strong>Nevím HASH kód z jízdenky</strong><p>
                    Zadejte své telefonní číslo. Kód Vám bude v zápětí doručen na Vámi 
                    zadané telefonní číslo formou SMS zprávy. Telefonní
                    číslo musí být shodné s telefonním číslem, na které byla vystavena SMS
                    jízdenka. Telefonní číslo zadávejte v plném mezinárodním formátu.
            Příklad - <b>+420777123456.</b></p></li>
            <li><strong>Vím HASH kód z jízdenky</strong><p>Zadejte své telefonní číslo i HASH kód z SMS jízdenky.
                    HASH kód je devítimístný kód ze SMS jízdenky. Příklad: <b>hxPRGWRyN</b>.
                    Telefonní číslo a HASH kód musí souhlasit, tzn., že SMS jízdenka s daným
                    HASH kódem byla vydána na uvedené telefonní číslo. HASH kód můžete
            použít z jakékoli Vaší SMS jízdenky.</p></li>
        </ul>
        <h2>Krok č.2</h2>
        <p>Vyplňte příslušné údaje pro vybranou variantu přihlášení</p>
        <h2>Krok č.3</h2>
        <p>Stiskněte tlačítko ODESLAT nebo PŘIHLÁSIT.</p>
    </div>
    </div>
    <div style="display:block;" id="jsNote">
        <p>
            Upozornění...
        </p>
        <p>
            Váš prohlížeč nemá zapnutý JavaScript. Prosím zkontrolujte nastavení a zapněte jej.
        </p>
        <p>
            Portál pro vystavení daňového dokladu DP města Ústí nad Labem, a.s.
        </p>
    </div>
    <div id="footer">
        <spring:message code="copyright"/>
    </div>
    <script type="text/javascript">
        //<!--
        document.getElementById('holder').style.display = 'block';
        document.getElementById('jsNote').style.display = 'none';
        //-->
    </script>
</body>
</html>        


