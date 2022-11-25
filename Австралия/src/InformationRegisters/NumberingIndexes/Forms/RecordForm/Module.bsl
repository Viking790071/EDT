#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	FillTypesList(Items.IndexObjectType.ChoiceList);
	
	If Parameters.Property("ObjectType") And ValueIsFilled(Parameters.ObjectType) Then 
		If Not ValueIsFilled(Parameters.CopyingValue) Then 
			Record.Object = New(Parameters.ObjectType);
		EndIf;
	EndIf;
	
	If Parameters.Property("Object") And ValueIsFilled(Parameters.Object) Then 
		RecordManager = InformationRegisters.NumberingIndexes.CreateRecordManager();
		RecordManager.Object = Parameters.Object;
		RecordManager.Read();
		If RecordManager.Selected() Then 
			ValueToFormAttribute(RecordManager, "Record");
		Else
			Record.Object = Parameters.Object;
		EndIf;
		Items.IndexObjectType.ReadOnly = True;
		Items.Object.ReadOnly = True;
	EndIf;
	
	If Record.Object = Undefined Then
		Items.Object.Enabled = False;
	Else
		IndexObjectType = TypeOf(Record.Object);
		Items.Object.Enabled = True;
	EndIf;
	
EndProcedure

&AtServer
Procedure OnWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If IndexObjectType = Type("CatalogRef.Companies") Then
		
		CompanyObject = Record.Object.GetObject();
		CompanyObject.Prefix = Record.Index;
		
		Try
			CompanyObject.Write();
		Except
			MessagePattern = NStr("en = 'Error occured while trying to update company prefix:
										|%1'; 
										|ru = 'При попытке обновления префикса организации произошла ошибка:
										|%1';
										|pl = 'Błąd wystąpił podczas próby aktualizacji prefiksu firmy:
										|%1';
										|es_ES = 'Se ha producido un error al intentar actualizar el prefijo de la empresa:
										|%1';
										|es_CO = 'Se ha producido un error al intentar actualizar el prefijo de la empresa:
										|%1';
										|tr = 'Şirket önekini güncellemeye çalışırken hata oluştu: 
										| %1';
										|it = 'Errore durante il tentativo di aggiornare il prefisso azienda:
										|%1';
										|de = 'Beim Versuch, das Firmenpräfix zu aktualisieren, ist ein Fehler aufgetreten:
										|%1'");
			MessageText = StringFunctionsClientServer.SubstituteParametersToString(
				MessagePattern,
				BriefErrorDescription(ErrorInfo()));
			CommonClientServer.MessageToUser(MessageText, , , , Cancel);
		EndTry;
		
	EndIf;
	
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure IndexObjectTypeOnChange(Item)
	
	If Not ValueIsFilled(IndexObjectType) Then
		Items.Object.Enabled = False;
		Record.Object = Undefined;
	Else
		Items.Object.Enabled = True;
		Record.Object = New(IndexObjectType);
	EndIf;
	
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillTypesList(TypesList) 
	
	InformationRegisters.NumberingIndexes.FillTypesList(TypesList);
	
EndProcedure

#EndRegion