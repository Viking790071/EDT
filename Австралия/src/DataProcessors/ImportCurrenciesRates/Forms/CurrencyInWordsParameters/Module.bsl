
#Region FormEventHandlers

&AtServer
Procedure OnCreateAtServer(Cancel, StandardProcessing)
	
	If Parameters.Property("AutoTest") Then // Return when a form is received for analysis.
		Return;
	EndIf;
	
	FillFormByObject();
EndProcedure

#EndRegion

#Region FormHeaderItemsEventHandlers

&AtClient
Procedure AmountNumberOnChange(Item)
	
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageOnChange(Item)
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, Waiting);
	
EndProcedure

&AtClient
Procedure InWordsField4HomeLanguageTextEditEnd(Item, Text, ChoiceData, DataGetParameters)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, DataGetParameters);
	
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageOnChange(Item)
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, Waiting);
	
EndProcedure

&AtClient
Procedure InWordsField8HomeLanguageTextEditEnd(Item, Text, ChoiceData, DataGetParameters)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, DataGetParameters);
	
EndProcedure

&AtClient
Procedure InWordsField1HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField2HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField3HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField5HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField6HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure InWordsField7HomeLanguageOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionalPartLengthOnChange(Item)
	SetAmountInWords(ThisObject);
EndProcedure

&AtClient
Procedure FractionalPartLengthAutoComplete(Item, Text, ChoiceData, DataGetParameters, Waiting)
	
	ChoiceData = AutoCompleteByChoiceList(Item, Text, Waiting);
	
EndProcedure

&AtClient
Procedure FractionalPartLengthTextEditEnd(Item, Text, ChoiceData, DataGetParameters)
	
	ChoiceData = TextEditEndByChoiceList(Item, Text, DataGetParameters);
	
EndProcedure

#EndRegion

#Region FormCommandHandlers

&AtClient
Procedure Apply(Command)
	Close(InWordsParametersInRussian(ThisObject));
EndProcedure

&AtClient
Procedure Cancel(Command)
	Close();
EndProcedure

#EndRegion

#Region Private

&AtServer
Procedure FillFormByObject()
	
	LoadInWordParameters();
	
	SetSignatureCaseParameters(ThisObject);
	SetAmountInWords(ThisObject);
	
EndProcedure

&AtClientAtServerNoContext
Function InWordsParametersInRussian(Form)
	
	Return Form.AmountInWordsField1Russian + ", "
			+ Form.AmountInWordsField2Russian + ", "
			+ Form.AmountInWordsField3Russian + ", "
			+ Lower(Left(Form.AmountInWordsField4Russian, 1)) + ", "
			+ Form.AmountInWordsField5Russian + ", "
			+ Form.AmountInWordsField6Russian + ", "
			+ Form.AmountInWordsField7Russian + ", "
			+ Lower(Left(Form.AmountInWordsField8Russian, 1)) + ", "
			+ Form.FractionalPartLength;
	
EndFunction

&AtClientAtServerNoContext
Procedure SetAmountInWords(Form)
	
	Form.AmountInWords = NumberInWords(Form.AmountNumber, , InWordsParametersInRussian(Form));
	
EndProcedure

&AtServer
Procedure LoadInWordParameters()
	
	// Reads parameters presented in words and fills in the
	
	ParameterString = StrReplace(Parameters.InWordsParameters, ",", Chars.LF);
	
	AmountInWordsField1Russian = TrimAll(StrGetLine(ParameterString, 1));
	AmountInWordsField2Russian = TrimAll(StrGetLine(ParameterString, 2));
	AmountInWordsField3Russian = TrimAll(StrGetLine(ParameterString, 3));
	
	Gender = TrimAll(StrGetLine(ParameterString, 4));
	
	If Lower(Gender) = "borough" Then
		AmountInWordsField4Russian = "Male";
	ElsIf Lower(Gender) = "railroad" Then
		AmountInWordsField4Russian = "Feminine";
	ElsIf Lower(Gender) = "with" Then
		AmountInWordsField4Russian = "Neuter";
	EndIf;
	
	AmountInWordsField5Russian = TrimAll(StrGetLine(ParameterString, 5));
	AmountInWordsField6Russian = TrimAll(StrGetLine(ParameterString, 6));
	AmountInWordsField7Russian = TrimAll(StrGetLine(ParameterString, 7));
	
	Gender = TrimAll(StrGetLine(ParameterString, 8));
	
	If Lower(Gender) = "borough" Then
		AmountInWordsField8Russian = "Male";
	ElsIf Lower(Gender) = "railroad" Then
		AmountInWordsField8Russian = "Feminine";
	ElsIf Lower(Gender) = "with" Then
		AmountInWordsField8Russian = "Neuter";
	EndIf;
	
	FractionalPartLength = TrimAll(StrGetLine(ParameterString, 9));
	
EndProcedure

&AtClientAtServerNoContext
Procedure SetSignatureCaseParameters(Form)
	
	// Declension of headings' parameters presented in words.
	
	Items = Form.Items;
	
	If Form.AmountInWordsField4Russian = "Feminine" Then
		Items.AmountInWordsField1Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField2Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	ElsIf Form.AmountInWordsField4Russian = "Male" Then
		Items.AmountInWordsField1Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField2Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	Else
		Items.AmountInWordsField1Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField2Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	EndIf;
	
	If Form.AmountInWordsField8Russian = "Feminine" Then
		Items.AmountInWordsField5Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField6Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	ElsIf Form.AmountInWordsField8Russian = "Male" Then
		Items.AmountInWordsField5Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField6Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	Else
		Items.AmountInWordsField5Russian.Title = NStr("ru = 'Одна'; en = 'One'; pl = 'Jeden';es_ES = 'Uno';es_CO = 'Uno';tr = 'Bir';it = 'Uno';de = 'Eins'");
		Items.AmountInWordsField6Russian.Title = NStr("ru = 'Две'; en = 'Two'; pl = 'Dwa';es_ES = 'Dos';es_CO = 'Dos';tr = 'İki';it = 'Due';de = 'Zwei'");
	EndIf;
	
EndProcedure

&AtClient
Function AutoCompleteByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			StandardProcessing = False;
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

&AtClient
Function TextEditEndByChoiceList(Item, Text, StandardProcessing)
	
	// Input management secondary function.
	
	StandardProcessing = False;
	
	For Each ChoiceItem In Item.ChoiceList Do
		If Upper(Text) = Upper(ChoiceItem.Presentation) Then
			StandardProcessing = True;
		ElsIf Upper(Text) = Upper(Left(ChoiceItem.Presentation, StrLen(Text))) Then
			StandardProcessing = False;
			Result = New ValueList;
			Result.Add(ChoiceItem.Value, ChoiceItem.Presentation);
			Return Result;
		EndIf;
	EndDo;
	
	Return Undefined;
	
EndFunction

#EndRegion

