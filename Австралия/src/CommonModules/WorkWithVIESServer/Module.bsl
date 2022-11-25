
#Region Public

Function VATCheckingResult(VATNumber) Export
	
	If Not ValueIsFilled(VATNumber) Then
		CommonClientServer.MessageToUser(NStr("en = 'VAT ID is not filled'; ru = 'Номер плательщика НДС не заполнен';pl = 'Nie wypełniono numeru VAT';es_ES = 'No se ha rellenado el identificador del IVA';es_CO = 'No se ha rellenado el identificador del IVA';tr = 'KDV kodu doldurulmadı';it = 'L''Id IVA non è compilato';de = 'USt.- IdNr. ist nicht ausgefüllt'"));
		Return Undefined;
	EndIf;
	
	CountryCode = Left(VATNumber, 2);
	VATNumberWithoutCode = TrimAll(Right(VATNumber, StrLen(VATNumber) - 2));
	
	Proxy = WSReferences.VIES.CreateWSProxy("urn:ec.europa.eu:taxud:vies:services:checkVat", "checkVatService", "checkVatPort");
	
	RequestDate	= Date(1, 1, 1);
	Valid		= False;
	Name		= "";
	Address		= "";
	
	Try
		Proxy.checkVat(CountryCode, VATNumberWithoutCode, RequestDate, Valid, Name, Address);
	Except
		RequestDate	= CurrentSessionDate();
		Valid		= False;
		Name		= "--";
		Address		= "--";
	EndTry;
	
	AnswerStructure =  New Structure();
	AnswerStructure.Insert("VIESQueryDate",			RequestDate);
	VIESValidationState = ?(Valid, Enums.VIESValidationStates.Valid, Enums.VIESValidationStates.NotValid);
	AnswerStructure.Insert("VIESValidationState",	VIESValidationState);
	AnswerStructure.Insert("VIESClientName",		Name);
	AnswerStructure.Insert("VIESClientAddress",		TrimAll(Address));
	
	Return AnswerStructure;
	
EndFunction

Procedure FillVATValidationAttributes(Form, Counterparty) Export
	
	If Not ValueIsFilled(Counterparty) Then
		
		SetEmptyState(Form);
		
	Else
		
		Query = New Query;
		Query.Text = "SELECT ALLOWED
		|	Validation.VIESValidationState AS VIESValidationState,
		|	Validation.VIESClientAddress AS VIESClientAddress,
		|	Validation.VIESClientName AS VIESClientName,
		|	Validation.VIESQueryDate AS VIESQueryDate
		|FROM
		|	InformationRegister.VIESVATNumberValidation AS Validation
		|WHERE
		|	Validation.Counterparty = &Counterparty";
		
		Query.SetParameter("Counterparty", Counterparty);
		
		QueryResult = Query.Execute();
		
		If QueryResult.IsEmpty() Then
			
			SetEmptyState(Form);
			
		Else
			
			SelectionDetailRecord = QueryResult.Select();
			SelectionDetailRecord.Next();
			FillPropertyValues(Form, SelectionDetailRecord);
			SetGroupVATState(Form.Items.GroupVATState, Form.VIESValidationState);
			
		EndIf;
		
	EndIf;
	
EndProcedure

Procedure SetEmptyState(Form) Export
	
	Form.VIESClientAddress		= "";
	Form.VIESClientName			= "";
	Form.VIESQueryDate			= Date(1, 1, 1);
	Form.VIESValidationState	= Enums.VIESValidationStates.EmptyRef();
	SetGroupVATState(Form.Items.GroupVATState, Enums.VIESValidationStates.EmptyRef());
	
EndProcedure

Procedure WriteVIESValidationResult(Form, Counterparty) Export
	
	RecordsToDel = InformationRegisters.VIESVATNumberValidation.CreateRecordSet();
	RecordsToDel.Filter.Counterparty.Set(Counterparty);
	RecordsToDel.Write();
	
	If ValueIsFilled(Form.VIESQueryDate) Then
		
		NewRecord = InformationRegisters.VIESVATNumberValidation.CreateRecordManager();
		NewRecord.Counterparty = Counterparty;
		FillPropertyValues(NewRecord, Form);
		NewRecord.Write(True);
		
	EndIf;
	
EndProcedure

Procedure SetGroupVATState(GroupVATState, ValidationState) Export
	
	GroupVATState.Title			= VIESStateString(ValidationState);
	GroupVATState.TitleTextColor	= VIESStateColor(ValidationState);
	
EndProcedure

Function VIESStateString(ValidationState) Export
	
	AnswerString = NStr("en = 'Not checked'; ru = 'Не проверено';pl = 'Niesprawdzone';es_ES = 'Sin verificar';es_CO = 'Sin verificar';tr = 'Kontrol edilmedi';it = 'Non controllato';de = 'Nicht überprüft'");
	
	If ValidationState = Enums.VIESValidationStates.Valid Then
		AnswerString = NStr("en = 'VAT valid'; ru = 'НДС допустимый';pl = 'VAT jest ważny';es_ES = 'IVA válido';es_CO = 'IVA válido';tr = 'KDV geçerli';it = 'IVA valida';de = 'USt. gültig'");
	ElsIf ValidationState = Enums.VIESValidationStates.NotValid Then
		AnswerString = NStr("en = 'VAT invalid'; ru = 'НДС недопустимый';pl = 'Numer VAT jest nieważny';es_ES = 'IVA inválido';es_CO = 'IVA inválido';tr = 'KDV geçersiz';it = 'IVA non valida';de = 'USt. ungültig'");
	EndIf;
	
	Return AnswerString;
	
EndFunction

Function VIESStateColor(ValidationState) Export
	
	AnswerColor = WebColors.RosyBrown;
	
	If ValidationState = Enums.VIESValidationStates.Valid Then
		AnswerColor = WebColors.LightSeaGreen;
	ElsIf ValidationState = Enums.VIESValidationStates.NotValid Then
		AnswerColor = WebColors.Red;
	EndIf;
	
	Return AnswerColor;
	
EndFunction

#EndRegion