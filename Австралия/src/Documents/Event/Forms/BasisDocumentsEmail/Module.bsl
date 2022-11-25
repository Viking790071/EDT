#Region FormEventsHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	AddressInBasisDocumentsStorage = Parameters.AddressInBasisDocumentsStorage;
	BasisDocuments.Load(GetFromTempStorage(AddressInBasisDocumentsStorage));
	
EndProcedure

#EndRegion

#Region FormCommandsHandlers

&AtClient
Procedure OK(Command)
	
	Cancel = False;
	
	CheckFillOfFormAttributes(Cancel);
	
	If Not Cancel Then
		WriteBasisDocumentsToStorage();
		Close(DialogReturnCode.OK);
	EndIf;

EndProcedure

#EndRegion

#Region CommonProceduresAndFunctions

// Procedure checks the correctness of the form attributes filling.
//
&AtClient
Procedure CheckFillOfFormAttributes(Cancel)
	
	// Attributes filling check.
	LineNumber = 0;
		
	For Each RowDocumentsBases In BasisDocuments Do
		LineNumber = LineNumber + 1;
		If Not ValueIsFilled(RowDocumentsBases.BasisDocument) Then
			Message = New UserMessage();
			Message.Text = StringFunctionsClientServer.SubstituteParametersToString(
				NStr("en = 'Please fill the ""Base document"" column in line #%1 of the ""Base documents"" list.'; ru = 'Необходимо указать документ-основание в строке %1 списка ""Документы-основания"".';pl = 'Proszę wypełnić kolumnę ""Dokument źródłowy"" w wierszu # %1 listy ""Dokument źródłowy"".';es_ES = 'Por favor rellene la columna de ""Documento básico"" en la línea #%1 de la lista de ""Documentos básicos"".';es_CO = 'Por favor rellene la columna de ""Documento básico"" en la línea #%1 de la lista de ""Documentos básicos"".';tr = 'Lütfen ""Temel belgeler"" listesindeki %1 satırındaki ""Temel belge"" sütununu doldurun.';it = 'Per piacere compila la colonna ""Documento di base"" nella linea #%1 dell''elenco ""Documenti di base""';de = 'Bitte füllen Sie die Spalte ""Basisdokument"" in der Zeile Nr %1 der Liste ""Basisdokumente"" aus.'"),
				String(LineNumber));
			Message.Field = "Document";
			Message.Message();
			Cancel = True;
		EndIf;
	EndDo;
	
EndProcedure

// The procedure places pick-up results in the storage.
//
&AtServer
Procedure WriteBasisDocumentsToStorage()
	
	BasisDocumentsInStorage = BasisDocuments.Unload(, "BasisDocument");
	PutToTempStorage(BasisDocumentsInStorage, AddressInBasisDocumentsStorage);
	
EndProcedure

#EndRegion
