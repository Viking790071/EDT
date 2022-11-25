
#Region Public

Function ReferenceByCode(Barcode) Export
	
	DocumentRef = Undefined;
	
	If StringFunctionsClientServer.OnlyNumbersInString(Barcode, False, False)
		AND TrimAll(Barcode) <> "" Then
		
		DecBarcode = Number(Barcode);
		HexBarcode = NumberToHexString(DecBarcode);
		
		While StrLen(HexBarcode) < 32 Do
			HexBarcode = "0" + HexBarcode;
		EndDo;
		
		FullUUID = 	Mid(HexBarcode, 1,  8)
			+ "-" + Mid(HexBarcode, 9,  4)
			+ "-" + Mid(HexBarcode, 13, 4)
			+ "-" + Mid(HexBarcode, 17, 4)
			+ "-" + Mid(HexBarcode, 21, 12);
		
		If StringFunctionsClientServer.IsUUID(FullUUID) Then
			
			RefUUID = New UUID(FullUUID);
			
			ObjectsManagers = New Array();
			
			For Each MetadataItem In Metadata.Documents Do
				ObjectsManagers.Add(Documents[MetadataItem.Name]);
			EndDo;
			
			For Each DocumentManager In ObjectsManagers Do
				
				RefByUUID = DocumentManager.GetRef(RefUUID);
				
				If Common.RefExists(RefByUUID) Then
					DocumentRef = RefByUUID;
					Break;
				EndIf;
				
			EndDo;
			
		EndIf;
		
	EndIf;
	
	Return DocumentRef;
	
EndFunction

Function CodeByReference(Ref) Export
	
	RefUUID = Ref.UUID();
	CleanUUID = "0x" + StrReplace(RefUUID, "-", "");
	NumberFromHexString = NumberFromHexString(CleanUUID);
	Return Format(NumberFromHexString, "NG = 100");
	
EndFunction

Procedure AddBarcodeToTableDocument(TemplateArea, Ref) Export
	
	If TemplateAreaContainBarcodePicture(TemplateArea) Then
		
		If GetFunctionalOption("UseBarcodesInPrintForms") Then
			
			Prototype = DataProcessors.PrintLabelsAndTags.GetTemplate("Prototype");
			MmsInPixel = Prototype.Drawings.Square100Pixels.Height / 100;
			
			BarcodeParameters = New Structure;
			Barcode = CodeByReference(Ref);
			BarcodeParameters.Insert("Width",		StrLen(Barcode)*10);
			BarcodeParameters.Insert("Height",		40);
			BarcodeParameters.Insert("Barcode",		Barcode);
			BarcodeParameters.Insert("CodeType",	4);
			BarcodeParameters.Insert("ShowText",	False);
			BarcodeParameters.Insert("SizeOfFont",	6);
			
			TemplateArea.Drawings.DocumentBarcode.Picture = EquipmentManagerServerCall.GetBarcodePicture(BarcodeParameters);
			
		Else
			
			TemplateArea.Drawings.Delete(TemplateArea.Drawings.DocumentBarcode);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure AddWidthBarcodeToTableDocument(TemplateArea, Ref) Export
	
	If TemplateAreaContainBarcodePicture(TemplateArea) Then
		
		If GetFunctionalOption("UseBarcodesInPrintForms") Then
			
			Prototype = DataProcessors.PrintLabelsAndTags.GetTemplate("Prototype");
			MmsInPixel = Prototype.Drawings.Square100Pixels.Height / 100;
			
			BarcodeParameters = New Structure;
			Barcode = CodeByReference(Ref);
			BarcodeParameters.Insert("Width",		StrLen(Barcode)*15);
			BarcodeParameters.Insert("Height",		200);
			BarcodeParameters.Insert("Barcode",		Barcode);
			BarcodeParameters.Insert("CodeType",	4);
			BarcodeParameters.Insert("ShowText",	False);
			BarcodeParameters.Insert("SizeOfFont",	6);
			
			TemplateArea.Drawings.DocumentBarcode.Picture = EquipmentManagerServerCall.GetBarcodePicture(BarcodeParameters);
			
		Else
			
			TemplateArea.Drawings.Delete(TemplateArea.Drawings.DocumentBarcode);
			
		EndIf;
		
	EndIf;
	
EndProcedure
// Function makes and returns action with document from "Barcode scanning events" register
//
// Parameters:
//   Document - DocumentRef - Document from barcode
//   User - CatalogRef.Users - current user
//
// Returns:
//   Structure - parameters of actions after changing:
//       * Open - Boolean - open (true) or notify (false)
//       * NotificationText - String - notification text about changing
//
Function ActionsAfterMakingScanningEvent(Document, User) Export
	
	ActionsStructure = New Structure;
	ActionsStructure.Insert("Open",				True);
	ActionsStructure.Insert("NotificationText",	"");
	
	DocumentMetadata = Document.Metadata();
	DocumentType = Common.MetadataObjectID(DocumentMetadata);
	
	Query = New Query;
	Query.Text = 
	"SELECT ALLOWED
	|	BarcodeScanningEvents.Action AS ScanningAction,
	|	0 AS Order
	|FROM
	|	InformationRegister.BarcodeScanningEvents AS BarcodeScanningEvents
	|WHERE
	|	BarcodeScanningEvents.DocumentType = &DocumentType
	|	AND BarcodeScanningEvents.UserGroup = &User
	|
	|UNION ALL
	|
	|SELECT
	|	BarcodeScanningEvents.Action,
	|	1
	|FROM
	|	InformationRegister.BarcodeScanningEvents AS BarcodeScanningEvents
	|		INNER JOIN Catalog.UserGroups.Content AS UserGroupsContent
	|		ON BarcodeScanningEvents.UserGroup = UserGroupsContent.Ref
	|WHERE
	|	BarcodeScanningEvents.DocumentType = &DocumentType
	|	AND UserGroupsContent.User = &User
	|
	|ORDER BY
	|	Order";
	
	Query.SetParameter("DocumentType", DocumentType);
	Query.SetParameter("User", User);
	
	QueryResult = Query.Execute();
	
	SelectionDetailRecords = QueryResult.Select();
	
	If SelectionDetailRecords.Next() Then
		
		ScanningAction = SelectionDetailRecords.ScanningAction;
		
		If Common.ObjectAttributeValue(ScanningAction, "Action") Then
			
			ActionsStructure.Open = False;
			
			DocumentObject = Document.GetObject();
			DocumentLocked = True;
			Try
				DocumentObject.Lock();
			Except
				DocumentLocked = False;
				TemplateText = NStr("en = 'Can''t lock the object %1'; ru = 'Невозможно заблокировать объект %1';pl = 'Nie można zablokować obiekt %1';es_ES = 'No se puede fijar el objeto %1';es_CO = 'No se puede fijar el objeto %1';tr = '%1 nesnesi kilitlenemiyor';it = 'Impossibile bloccare l''oggetto %1';de = 'Das Objekt %1 kann nicht gesperrt werden'");
				MessageText = StringFunctionsClientServer.SubstituteParametersToString(TemplateText, Document)
					+ Chars.LF
					+ ErrorDescription();
				DriveServer.ShowMessageAboutError(Undefined, MessageText);
			EndTry;
			
			If DocumentLocked Then
				
				NotificationText = Common.SubjectString(Document);
				
				For Each AttributeLine In ScanningAction.ChangingAttributes Do
					
					If AttributeLine.Change Then
						
						AttributePresentation = "";
						
						If (AttributeLine.OperationKind = 1) Then
							
							AttributeMetadata = DocumentMetadata.Attributes.Find(AttributeLine.Attribute);
							
							If AttributeMetadata <> Undefined Then
								AttributePresentation = AttributeMetadata.Synonym;
								DocumentObject[AttributeLine.Attribute] = AttributeLine.Value;
							EndIf;
							
						Else
							
							Property = ChartsOfCharacteristicTypes.AdditionalAttributesAndInfo.FindByDescription(AttributeLine.Attribute);
							If PropertyManager.CheckObjectProperty(Document, Property) Then
								
								If AttributeLine.OperationKind = 2 Then
									
									RowArray = DocumentObject.AdditionalAttributes.FindRows(New Structure("Property", Property));
									If RowArray.Count() Then
										PropertyString = RowArray[0];
									Else
										PropertyString = DocumentObject.AdditionalAttributes.Add();
									EndIf;
									PropertyString.Property = Property;
									PropertyString.Value = AttributeLine.Value;
									
								ElsIf AttributeLine.OperationKind = 3 Then
									
									RecordManager = InformationRegisters.AdditionalInfo.CreateRecordManager();
									
									RecordManager.Object = Document;
									RecordManager.Property = Property;
									RecordManager.Value = AttributeLine.Value;
									
									Try
										RecordManager.Write();
									Except
										ErrorDescription = StringFunctionsClientServer.SubstituteParametersToString(
											NStr("en = 'Cannot save register %1'; ru = 'Не удалось записать регистр %1';pl = 'Nie można zapisać rejestru %1';es_ES = 'Ha ocurrido un error al guardar el registro %1';es_CO = 'Ha ocurrido un error al guardar el registro %1';tr = '%1 kaydı yapılamıyor';it = 'Impossibile salvare il registro %1';de = 'Fehler beim Speichern des Registers ""%1""'"),
											BriefErrorDescription(ErrorInfo()));
										
										WriteLogEvent(
											NStr("en = 'Error writing additional information register'; ru = 'Ошибка при записи дополнительного регистра сведений';pl = 'Błąd podczas zapisywania dodatkowego rejestru informacji';es_ES = 'Error al guardar el registro de información adicional';es_CO = 'Error al guardar el registro de información adicional';tr = 'Ek bilgi kaydı kaydedilirken hata oluştu';it = 'Errore durante la scrittura registro informazioni aggiuntive';de = 'Fehler beim Speichern des Zusatzinformationsregisters'", CommonClientServer.DefaultLanguageCode()),
											EventLogLevel.Error,
											Metadata.InformationRegisters.AdditionalInfo,
											,
											ErrorDescription);
									EndTry;
									
								EndIf;
								
								AttributePresentation = Property.Title;
								
							EndIf;
							
						EndIf;
						
						If ValueIsFilled(AttributePresentation) Then
							
							AttributeSetMessage = StringFunctionsClientServer.SubstituteParametersToString(
								NStr("en = 'Attribute ''%1'' set to value ''%2'''; ru = 'Установлено значение %2 реквизита %1';pl = 'Atrybut ''%1'' ustawiony na wartość ''%2''';es_ES = 'Atributo ''%1'' tiene el valor ''%2''';es_CO = 'Atributo ''%1'' tiene el valor ''%2''';tr = '''%1'' özniteliği ''%2'' değerine ayarlandı';it = 'Attributo ""%1"" impostato al valore ""%2""';de = 'Attribut ''%1'' auf Wert gesetzt ''%2'''"),
								AttributePresentation,
								AttributeLine.Value);
							
							NotificationText = NotificationText
								+ Chars.LF
								+ AttributeSetMessage;
							
						EndIf;
						
					EndIf;
					
				EndDo;
				
				ActionsStructure.NotificationText = NotificationText;
				
			EndIf;
			
			DocumentObject.Write();
			
		EndIf;
		
	EndIf;
	
	Return ActionsStructure;
	
EndFunction

#EndRegion

#Region Private

Function NumberToHexString(Val DecimalNumber)
	
	Hex = "";
	
	While DecimalNumber > 0 Do
		Mod = DecimalNumber % 16;
		DecimalNumber = (DecimalNumber - Mod) / 16;
		Hex = Mid("0123456789abcdef", Mod + 1, 1) + Hex;
	EndDo;
	
	Return Hex;
	
EndFunction

Function TemplateAreaContainBarcodePicture(TemplateArea)
	
	Result = False;
	
	For Each Drawing In TemplateArea.Drawings Do
		
		If Drawing.Name = "DocumentBarcode" Then
			Result = True;
			Break;
		EndIf;
		
	EndDo;
	
	Return Result;
	
EndFunction

#EndRegion