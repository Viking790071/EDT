
#Region EventHandlers

&AtClient
Procedure CommandProcessing(CommandParameter, CommandExecuteParameters)
	
	ShowMessageBox(,
		StringFunctionsClientServer.SubstituteParametersToString(
			NStr("ru = 'Время сеанса: %1
				|На сервере: %2
				|На клиенте: %3
				|
				|Время сеанса - это время сервера,
				|приведенное к часовому поясу клиента.'; 
				|en = 'Session time: %1
				|Server time: %2
				|Client time: %3
				|
				|The session time is the server time
				|converted to the client time zone.'; 
				|pl = 'Czas sesji: %1
				|Na serwerze: %2
				|Na kliencie: %3
				|
				|Czas sesji - jest to czas serwera,
				|sprowadzony do strefy czasowej klienta.';
				|es_ES = 'Tiempo de la sesión: %1
				|En el servidor: %2
				|En el cliente: %3
				|
				|Tiempo de la sesión es el tiempo del servidor
				| relacionado con la zona horaria del cliente.';
				|es_CO = 'Tiempo de la sesión: %1
				|En el servidor: %2
				|En el cliente: %3
				|
				|Tiempo de la sesión es el tiempo del servidor
				| relacionado con la zona horaria del cliente.';
				|tr = 'Oturum süresi: %1Sunucuda: %2
				|İstemcide: %3Oturum süresi, 
				|
				|
				|istemci saat dilimine göre bir 
				|sunucu saatidir.';
				|it = 'Ora sessione: %1
				|Ora server: %2
				|Ora client: %3
				|
				|L''ora della sessione è quella del server
				|convertita nella zona oraria del client.';
				|de = 'Session-Zeit: %1
				|Auf dem Server: %2
				|Auf dem Client: %3
				|
				|Session-Zeit ist die Zeit des Servers,
				|die in der Zeitzone des Clients angegeben ist.'"),
			Format(CommonClient.SessionDate(), "DLF=T"),
			Format(ServerDate(), "DLF=T"),
			Format(CurrentDate(), "DLF=T")));
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Function ServerDate()
	
	Return CurrentDate();
	
EndFunction

#EndRegion