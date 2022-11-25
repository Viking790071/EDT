#Region EventHandlers

&AtServer
Procedure OnReadAtServer(CurrentObject)
	
	If CurrentObject.DataType = Enums.APICacheDataTypes.InterfaceVersions Then
		
		Data = CurrentObject.Data.Get();
		Body = Common.ValueToXMLString(Data);
		
	ElsIf CurrentObject.DataType = Enums.APICacheDataTypes.WebServiceDetails Then
		
		TempFile = GetTempFileName("xml");
		
		BinaryData = CurrentObject.Data.Get();
		BinaryData.Write(TempFile);
		
		TextDocument = New TextDocument();
		TextDocument.Read(TempFile);
		
		Body = TextDocument.GetText();
		
		DeleteFiles(TempFile);
		
	EndIf;
	
EndProcedure

&AtServer
Procedure BeforeWriteAtServer(Cancel, CurrentObject, WriteParameters)
	
	If CurrentObject.DataType = Enums.APICacheDataTypes.InterfaceVersions Then
		
		Data = Common.ValueFromXMLString(Body);
		CurrentObject.Data = New ValueStorage(Data);
		
	ElsIf CurrentObject.DataType = Enums.APICacheDataTypes.WebServiceDetails Then
		
		TempFile = GetTempFileName("xml");
		
		TextDocument = New TextDocument();
		TextDocument.SetText(Body);
		TextDocument.Write(TempFile);
		
		BinaryData = New BinaryData(TempFile);
		CurrentObject.Data = New ValueStorage(BinaryData);
		
		DeleteFiles(TempFile);
		
	EndIf;
	
EndProcedure

#EndRegion