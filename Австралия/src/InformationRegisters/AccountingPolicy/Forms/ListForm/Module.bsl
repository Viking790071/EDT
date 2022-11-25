#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	CommonClientServer.SetDynamicListParameter(List, 
													"CreditNote", 
													NStr("en = 'Credit note document only'; ru = 'Только кредитовое авизо';pl = 'Tylko dokument noty kredytowej';es_ES = 'Solo el documento de la nota de crédito';es_CO = 'Solo el documento de la nota de crédito';tr = 'Yalnızca Alacak dekontu belgesi';it = 'Solo documento nota di Credito';de = 'Nur Gutschrift-Beleg'"),
													True); 
	CommonClientServer.SetDynamicListParameter(List,
													"CreditNoteAndGoodsReceipt", 
													NStr("en = 'Credit note and Goods receipt documents'; ru = 'Документы ""Кредитовое авизо"" и ""Поступление товаров""';pl = 'Nota kredytowa i dokumenty Przyjęcia towarów';es_ES = 'Documentos de la Nota de crédito y la Recepción de mercancías';es_CO = 'Documentos de la Nota de crédito y la Recepción de mercancías';tr = 'Alacak dekontu ve Ambar girişi belgeleri';it = 'Documenti di note di credito e ricezione merci';de = 'Gutschrift und Wareneingangsbelege'"),
													True); 
	CommonClientServer.SetDynamicListParameter(List,
													"DebitNote", 
													NStr("en = 'Debit note document only'; ru = 'Только дебетовое авизо';pl = 'Tylko dokument noty debetowej';es_ES = 'Solo el documento de la nota de débito';es_CO = 'Solo el documento de la nota de débito';tr = 'Yalnızca Borç dekontu belgesi';it = 'Solo documento nota di Debito';de = 'Nur Lastschriftbeleg'"),
													True); 
	CommonClientServer.SetDynamicListParameter(List, 
													"DebitNoteAndGoodsIssue", 
													NStr("en = 'Debit note and Goods issue documents'; ru = 'Документы ""Дебетовое авизо"" и ""Отпуск товаров""';pl = 'Nota debetowa i dokumenty Wydanie zewnętrzne';es_ES = 'Documentos de Nota de débito y Expedición de mercancías';es_CO = 'Documentos de Nota de débito y Expedición de mercancías';tr = 'Borç dekontu ve Ambar çıkışı belgeleri';it = 'Documenti di note di debito e spedizioni merce';de = 'Lastschrift und Warenausgangsbelege'"),
													True);
	
EndProcedure

#EndRegion

#Region FormTableItemsEventHandlersList

&AtClient
Procedure ListBeforeDeleteRow(Item, Cancel)
	
	ClearMessages();
	
	CurRow = Item.CurrentData;
	
	ParametersData = New Structure;
	ParametersData.Insert("Companies", CurRow.Company);
	ParametersData.Insert("Period", CurRow.Period);
	
	If CheckPeriodOnClosingDates(CurRow.Company, CurRow.Period) Then
		TextMessage = NStr("en = 'Cannot delete the accounting policy. Its effective period is within the closed period.'; ru = 'Не удалось удалить учетную политику. Период ее действия находится в пределах закрытого периода.';pl = 'Nie można usunąć polityki rachunkowości. Jej okres ważności mieści się w zamkniętym okresie.';es_ES = 'No se puede borrar la política de contabilidad. Su período de vigencia está dentro del período cerrado.';es_CO = 'No se puede borrar la política de contabilidad. Su período de vigencia está dentro del período cerrado.';tr = 'Muhasebe politikası silinemiyor. Yürürlük dönemi kapanış dönemi içinde.';it = 'Impossibile eliminare la politica contabile. Il periodo effettivo è incluso nel periodo chiuso.';de = 'Fehler beim Löschen der Bilanzierungsrichtlinien. Deren Gültigkeitsdauer liegt im geschlossenen Zeitraum.'");
		ShowMessageBox(Undefined, TextMessage);
		Cancel = True;
		Return;
	EndIf;
	
	If Not ModifyDeleteIsAllowed(ParametersData) Then
		
		CommonClientServer.MessageToUser(
			NStr("en = 'There are documents which were created with the current accounting policy setting. Cannot delete the current setting.'; ru = 'В базе содержатся документы, которые были созданы с учетом текущей настройки учетной политики. Не удалось удалить текущую настройку.';pl = 'Istnieją dokumenty, utworzone z bieżącym ustawieniem polityki rachunkowości. Nie można usunąć bieżącego ustawienia.';es_ES = 'Hay documentos que se han creado con la configuración actual de la política de contabilidad. No se puede borrar la configuración actual.';es_CO = 'Hay documentos que se han creado con la configuración actual de la política de contabilidad. No se puede borrar la configuración actual.';tr = 'Mevcut muhasebe politikası ayarına göre oluşturulan belgeler var. Mevcut ayar silinemez.';it = 'Ci sono documenti creati con l''impostazione di politica contabile corrente. Impossibile eliminare l''impostazione corrente.';de = 'Es gibt Dokumente die mit den aktuellen Einstellungen der Bilanzierungsrichtlinien erstellt wurden.Fehler beim Löschen von aktueller Einstellung.'")
			,
			,
			,
			,
			Cancel);
		
	EndIf;
	
	TypesOfAccountingArray = New Array;
	DeleteComanyTypesOfAccounting(CurRow.Company, CurRow.Period, TypesOfAccountingArray, Cancel);
	
	MessageTemplate = NStr("en = 'Type of accounting %1 is set inactive on %2 accounting policy settings. Remove it first and try again.'; ru = 'Тип бухгалтерского учета %1 не активирован в настройках учетной политики %2. Удалите его и повторите попытку.';pl = 'Typ rachunkowości %1 jest ustawiony na %2 nieaktywne ustawienia polityki rachunkowości. Najpierw usuń go i spróbuj ponownie.';es_ES = 'El tipo de contabilidad %1 está inactivo en las configuraciones %2 de la política de contabilidad. Primero elimínelo e inténtelo de nuevo.';es_CO = 'El tipo de contabilidad %1 está inactivo en las configuraciones %2 de la política de contabilidad. Primero elimínelo e inténtelo de nuevo.';tr = '%1 muhasebe türü, %2 muhasebe politikası ayarlarında inaktif olarak ayarlı. Bunu çıkarıp tekrar deneyin.';it = 'Tipo di contabilità %1 impostata su inattivo nelle%2 impostazioni di politica contabile. Rimuoverla e riprovare.';de = 'Typ der Buchhaltung%1 ist als Inaktiv für %2 Einstellungen der Bilanzierungsrichtlinien festgesetzt. Löschen Sie ihn zuerst und dann versuchen Sie erneut.'");
	For Each TypesOfAccountingStructure In TypesOfAccountingArray Do
		
		CommonClientServer.MessageToUser(
			StrTemplate(
				MessageTemplate,
				TypesOfAccountingStructure.TypeOfAccounting,
				Format(TypesOfAccountingStructure.Period, "DLF=D")));
				
	EndDo;
	
EndProcedure

#EndRegion

#Region Private

&AtServerNoContext
Function ModifyDeleteIsAllowed(ParametersData)
	
	Return InformationRegisters.AccountingPolicy.ModifyDeleteIsAllowed(ParametersData);
	
EndFunction

&AtServer
Function CheckPeriodOnClosingDates(Company, Date)
	
	Return InformationRegisters.AccountingPolicy.CheckPeriodOnClosingDates(Company, Date)
	
EndFunction

&AtServer
Function DeleteComanyTypesOfAccounting(Company, Date, ErrorMessages, Cancel)
	
	InformationRegisters.CompaniesTypesOfAccounting.DeleteRecords(Company, Date, ErrorMessages, Cancel);
	
EndFunction

#EndRegion
