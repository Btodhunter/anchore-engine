# coding: utf-8

from __future__ import absolute_import
from datetime import date, datetime  # noqa: F401

from typing import List, Dict  # noqa: F401

from anchore_engine.services.policy_engine.api.models.base_model_ import Model
from anchore_engine.services.policy_engine.api.models.feed_metadata import FeedMetadata  # noqa: F401,E501
from anchore_engine.services.policy_engine.api import util


class FeedMetadataListing(Model):
    """NOTE: This class is auto generated by the swagger code generator program.

    Do not edit the class manually.
    """

    def __init__(self):  # noqa: E501
        """FeedMetadataListing - a model defined in Swagger

        """
        self.swagger_types = {
        }

        self.attribute_map = {
        }

    @classmethod
    def from_dict(cls, dikt):
        """Returns the dict as a model

        :param dikt: A dict.
        :type: dict
        :return: The FeedMetadataListing of this FeedMetadataListing.  # noqa: E501
        :rtype: FeedMetadataListing
        """
        return util.deserialize_model(dikt, cls)