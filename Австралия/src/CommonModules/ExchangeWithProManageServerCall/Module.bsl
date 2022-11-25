#Region Public

Function GetStatusOfLastExchange() Export
	
	StatusOfLastExchange = New Structure;
	Title = NStr("en = 'Last sync with ProManage: %1'; ru = 'Последняя синхронизация с ProManage: %1';pl = 'Ostatnia synchronizacja z ProManage: %1';es_ES = 'Última sincronización con ProManage: %1';es_CO = 'Última sincronización con ProManage: %1';tr = 'ProManage ile son senkronizasyon: %1';it = 'Ultima sincronizzazione con ProManage: %1';de = 'Letzte Synchronisierung mit ProManage: %1'");
	HasError = False;
		
	Query = New Query;
	Query.Text = 
	"SELECT TOP 2
	|	StatesOfExchangeWithProManage.ExchangeExecutionResult AS ExchangeExecutionResult,
	|	StatesOfExchangeWithProManage.EndDate AS EndDate
	|FROM
	|	InformationRegister.StatesOfExchangeWithProManage AS StatesOfExchangeWithProManage
	|WHERE
	|	StatesOfExchangeWithProManage.ActionOnExchange = VALUE(Enum.ActionsOnExchange.DataImport)
	|
	|ORDER BY
	|	StatesOfExchangeWithProManage.EndDate DESC";
	
	QueryResult = Query.Execute();
	Selection = QueryResult.Select();
	
	If Selection.Count() <> 0 Then
		
		While Selection.Next() Do
			
			If Selection.ExchangeExecutionResult = Enums.ExchangeExecutionResults.Completed Then
				
				Title = StringFunctionsClientServer.SubstituteParametersToString(
				Title,
				Selection.EndDate);
				
				Break;
			Else		
				Title = NStr("en = 'Last attempt to sync with ProManage failed. Last successful sync: %1'; ru = 'Последняя попытка синхронизации с ProManage была неудачной. Последняя успешная синхронизация: %1';pl = 'Ostatnia próba synchronizacji z ProManage nie powiodła się. Ostatnia pomyślna synchronizacja: %1';es_ES = 'El último intento de sincronización con ProManage ha fallado. Última sincronización con éxito: %1';es_CO = 'El último intento de sincronización con ProManage ha fallado. Última sincronización con éxito: %1';tr = 'ProManage ile son senkronizasyon girişimi başarısız oldu. Son başarılı senkronizasyon: %1';it = 'Ultimo tentativo di sincronizzazione con ProManage fallito. Ultimo tentativo riuscito: %1';de = 'Fehlerhafter letzter Versuch mit ProManage zu synchronisieren. Letzte erfolgreiche Synchronisierung: %1'");
				HasError = True;
			EndIf;
			
		EndDo;
		
	Else
		Title = NStr("en = 'ProManage sync has never run'; ru = 'Синхронизация с ProManage не выполнялась';pl = 'Synchronizacja ProManage nie była jeszcze uruchamiana';es_ES = 'La sincronización con ProManage nunca se ha ejecutado';es_CO = 'La sincronización con ProManage nunca se ha ejecutado';tr = 'ProManage senkronizasyonu hiç çalışmadı';it = 'La sincronizzazione ProManage non è mai stata eseguita';de = 'ProManage ist niemals gelaufen'");
	EndIf;
	
	Title = StringFunctionsClientServer.SubstituteParametersToString(Title, NStr("en = 'never'; ru = 'никогда';pl = 'nigdy';es_ES = 'nunca';es_CO = 'nunca';tr = 'hiç bir zaman';it = 'mai';de = 'niemals'"));
	
	StatusOfLastExchange.Insert("Title", Title);
	Return StatusOfLastExchange;
	
EndFunction

#EndRegion