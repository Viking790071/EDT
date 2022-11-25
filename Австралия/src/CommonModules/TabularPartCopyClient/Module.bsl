
#Region ProgramInterface

Function CanCopyRows(TP, TPCurrentData) Export
	
	If TPCurrentData <> Undefined AND TP.Count() <> 0 Then
		Return True;
	EndIf;
	
	Return False;
	
EndFunction

Procedure NotifyUserCopyRows(CopiedCount) Export
	
	TitleText = NStr("en = 'Lines are copied'; ru = 'Строки скопированы';pl = 'Wiersze zostały skopiowane';es_ES = 'Líneas se han copiado';es_CO = 'Líneas se han copiado';tr = 'Satırlar kopyalandı';it = 'Le righe sono copiate';de = 'Zeilen werden kopiert'"); // Rows are copied
	MessageText = NStr("en = 'Lines are copied to the clipboard (%CopiedCount%)'; ru = 'В буфер обмена скопированы строки (%CopiedCount%)';pl = 'Wiersze zostały skopiowane schowka (%CopiedCount%)';es_ES = 'Líneas se han copiado al portapapeles (%CopiedCount%)';es_CO = 'Líneas se han copiado al portapapeles (%CopiedCount%)';tr = 'Satırlar panoya kopyalandı (%CopiedCount%)';it = 'Le rige sono copiate negli appunti (%CopiedCount%)';de = 'Zeilen werden in die Zwischenablage kopiert (%CopiedCount%)'");  //Rows are copied to clipboard
	MessageText = StrReplace(MessageText, "%CopiedCount%", CopiedCount);
	
	ShowUserNotification(TitleText,, MessageText);
	
	Notify("TabularPartCopyRowsClipboard");
	
EndProcedure

Procedure NotifyUserPasteRows(CopiedCount, PastedCount) Export
	
	TitleText = NStr("en = 'Lines are inserted'; ru = 'Строки вставлены';pl = 'Wiersze zostały dodane';es_ES = 'Líneas se han insertado';es_CO = 'Líneas se han insertado';tr = 'Satırlar eklendi';it = 'Le righe sono inseriti';de = 'Zeilen werden eingefügt'");
	MessageText = NStr("en = 'Rows are inserted from the clipboard (%PastedCount% of %CopiedCount%)'; ru = 'Из буфера обмена вставлены строки (%PastedCount% из %CopiedCount%)';pl = 'Wiersze zostały wstawione ze schowka (%PastedCount% z%CopiedCount%)';es_ES = 'Filas se han insertado del portapapeles (%PastedCount% de %CopiedCount%)';es_CO = 'Filas se han insertado del portapapeles (%PastedCount% de %CopiedCount%)';tr = 'Satırlar panodan eklendi (%PastedCount% of %CopiedCount%)';it = 'Le rige (%PastedCount% di %CopiedCount%) vengono inserite dagli appunti';de = 'Zeilen werden aus der Zwischenablage eingefügt (%PastedCount% von%CopiedCount%)'");
	MessageText = StrReplace(MessageText, "%PastedCount%", PastedCount);
	MessageText = StrReplace(MessageText, "%CopiedCount%", CopiedCount);
	
	ShowUserNotification(TitleText,, MessageText);
	
EndProcedure

Procedure NotificationProcessing(Items, TPName) Export
	
	SetButtonsVisibility(Items, TPName, True);
	
EndProcedure

#EndRegion

#Region ServiceProceduresAndFunctions

Procedure SetButtonsVisibility(FormItems, TPName, IsCopiedRows)
	
	FormItems[TPName + "CopyRows"].Enabled = True;
	
	If IsCopiedRows Then
		FormItems[TPName + "PasteRows"].Enabled = True;
	Else
		FormItems[TPName + "PasteRows"].Enabled = False;
	EndIf;
	
EndProcedure

#EndRegion
