module UsersHelper
	def login_with_google
<<HEREDOC
<div style="display:inline-block; color:#fff">
	<div style="display:inline-block; margin: 0; padding:5px; background-color:#99f"><i class="fa fa-google" style="width:16px; height:15px"></i></div><div style="display:inline-block; margin:0; padding:5px; background-color:#88f"> Continue with Google</div>
</div>
HEREDOC
	end

	def user_link(user, anonymize = false)
		if user.present?
			if anonymize
				anonymization_icon = content_tag(:i, '', class: "fa fa-user-secret", "aria-hidden" => "true", title: "anonymized")
				if current_user.present? && (current_user.root? || current_user == user)
					link_to safe_join([user.username, ' ', anonymization_icon]), show_user_path(user.username), style: 'display:block'
				else
					anonymization_icon
				end
			else
				link_to user.username, show_user_path(user.username), style: 'display:block'
			end
		else
			'Unknown'
		end
	end

	def user_name(user, anonymize = false)
		if user.present?
			if anonymize
				'anonymized'
			else
				user.username
			end
		else
			'Unknown'
		end
	end
end
